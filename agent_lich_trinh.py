import os
import io
import base64
import re
from dotenv import load_dotenv
from datetime import date, timedelta, datetime
import logging

from fastapi import FastAPI, Depends, HTTPException, status, File, UploadFile, Form, Request
from fastapi.responses import RedirectResponse
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from sqlalchemy.engine.base import Engine

from supabase import create_client, Client
from gtts import gTTS
import speech_recognition as sr
from pydub import AudioSegment

from langchain.agents import AgentExecutor, create_tool_calling_agent
from langchain.tools import tool
from langchain_core.chat_history import BaseChatMessageHistory
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.runnables.history import RunnableWithMessageHistory
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.chat_message_histories import ChatMessageHistory

# Import hàm xử lý thời gian từ module utils
from utils.thoi_gian_tu_nhien import parse_natural_time
from app_dependencies import get_current_user_id, engine, supabase
from payment_service import router as payment_router

# --- 1. CẤU HÌNH & KẾT NỐI ---
load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
# DATABASE_URL, SUPABASE_URL, SUPABASE_KEY are now loaded in app_dependencies.py

if not GEMINI_API_KEY:
    raise ValueError("❌ Thiếu GEMINI_API_KEY trong file .env")

# engine and supabase are imported from app_dependencies

llm_brain = ChatGoogleGenerativeAI(model="gemini-2.5-flash", google_api_key=GEMINI_API_KEY, temperature=0.7)

# --- 2. XÁC THỰC NGƯỜI DÙNG ---
# get_current_user_id is imported from app_dependencies

# --- 3. CÁC HÀM XỬ LÝ GIỌNG NÓI (Giữ nguyên) ---
def clean_text_for_speech(text: str) -> str:
    cleaned_text = text.replace('*', '')
    cleaned_text = cleaned_text.replace('_', '')
    cleaned_text = re.sub(r'^\s*-\s*', '. ', cleaned_text, flags=re.MULTILINE)
    return cleaned_text

def text_to_base64_audio(text: str) -> str:
    try:
        speech_text = clean_text_for_speech(text)
        tts = gTTS(speech_text, lang='vi', slow=False)
        audio_fp = io.BytesIO()
        tts.write_to_fp(audio_fp)
        audio_fp.seek(0)
        audio_bytes = audio_fp.read()
        return base64.b64encode(audio_bytes).decode('utf-8')
    except Exception as e:
        logger.error(f"Lỗi TTS: {e}")
        return ""

async def audio_to_text(audio_file: UploadFile) -> str:
    r = sr.Recognizer()
    try:
        audio_bytes = await audio_file.read()
        audio_fp = io.BytesIO(audio_bytes)
        sound = AudioSegment.from_file(audio_fp)

        if len(sound) < 500:
            raise HTTPException(status_code=400, detail="File âm thanh quá ngắn. Vui lòng nhấn giữ nút micro để nói.")

        wav_fp = io.BytesIO()
        sound.export(wav_fp, format="wav")
        wav_fp.seek(0)

        with sr.AudioFile(wav_fp) as source:
            audio_data = r.record(source)
            try:
                text = r.recognize_google(audio_data, language="vi-VN")
                logger.info(f"🎤 Văn bản nhận dạng được: {text}")
                return text
            except sr.UnknownValueError:
                raise HTTPException(status_code=400, detail="Rất tiếc, tôi không nghe rõ bạn nói. Vui lòng thử nói chậm và rõ ràng hơn.")
            except sr.RequestError as e:
                raise HTTPException(status_code=503, detail=f"Dịch vụ nhận dạng giọng nói tạm thời không khả dụng. Lỗi: {e}")

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        logger.error(f"Lỗi xử lý audio: {e}")
        raise HTTPException(status_code=500, detail=f"Đã xảy ra lỗi không mong muốn khi xử lý file âm thanh.")

# --- 4. HÀM HỖ TRỢ NGHIỆP VỤ (MỚI) ---

def _get_task_id_from_title(connection, user_id: str, title: str) -> int | None:
    """
    Hàm nội bộ tìm task_id dựa trên tiêu đề.
    Ưu tiên tìm task chưa hoàn thành và khớp nhất.
    """
    # 1. Thử tìm khớp chính xác (case-insensitive)
    query_exact = text("SELECT id FROM tasks WHERE user_id = :user_id AND lower(title) = lower(:title) ORDER BY is_completed ASC, created_at DESC LIMIT 1;")
    result = connection.execute(query_exact, {"user_id": user_id, "title": title}).fetchone()
    if result:
        return result.id

    # 2. Thử tìm khớp ILIKE (chứa)
    query_like = text("SELECT id FROM tasks WHERE user_id = :user_id AND unaccent(title) ILIKE unaccent(:title_like) ORDER BY is_completed ASC, created_at DESC LIMIT 1;")
    result = connection.execute(query_like, {"user_id": user_id, "title_like": f"%{title}%"}).fetchone()
    if result:
        return result.id
    
    return None

# --- 5. CÁC CÔNG CỤ (TOOLS) CHO AGENT (NÂNG CẤP) ---

@tool
def lay_ten_nguoi_dung(user_id: str) -> str:
    """Lấy tên của người dùng hiện tại từ cơ sở dữ liệu để cá nhân hóa cuộc trò chuyện."""
    try:
        with engine.connect() as connection:
            query = text("SELECT name FROM public.profiles WHERE id = :user_id;")
            result = connection.execute(query, {"user_id": user_id}).fetchone()
            if result and result.name:
                return f"Tên của người dùng là {result.name}."
            else:
                return "Không tìm thấy tên người dùng. Cứ trả lời bình thường mà không cần gọi tên."
    except Exception as e:
        return f"Lỗi khi lấy tên người dùng: {e}. Cứ trả lời bình thường."

@tool
def tao_task_don_le(tieu_de: str, user_id: str, mo_ta: str | None = None, deadline: str | None = None, priority: str | None = None) -> str:
    """
    Tạo một CÔNG VIỆC (task) mới mà KHÔNG cần lịch trình (schedule) cụ thể.
    Chỉ dùng khi người dùng nói 'tạo task', 'thêm việc cần làm', 'tạo nhiệm vụ', 'deadline'.
    Không dùng khi người dùng nói 'đặt lịch', 'hẹn'.
    priority phải là một trong ['low', 'medium', 'high'].
    """
    try:
        # Xử lý deadline (nếu có)
        deadline_iso = None
        if deadline:
            parsed_time = parse_natural_time(deadline)
            deadline_iso = parsed_time[0].isoformat() # Lấy start_time làm deadline

        with engine.connect() as connection:
            with connection.begin() as transaction:
                query = text("""
                    INSERT INTO tasks (user_id, title, description, deadline, priority, status)
                    VALUES (:user_id, :title, :description, :deadline, :priority, 'todo')
                    RETURNING id;
                """)
                result = connection.execute(
                    query,
                    {
                        "user_id": user_id,
                        "title": tieu_de,
                        "description": mo_ta,
                        "deadline": deadline_iso,
                        "priority": priority if priority in ['low', 'medium', 'high'] else None
                    }
                )
                task_id = result.scalar_one_or_none()
                transaction.commit()
                return f"✅ Đã tạo công việc mới: '{tieu_de}' (ID: {task_id})."
    except Exception as e:
        return f"❌ Lỗi khi tạo công việc: {e}"

@tool
def tao_lich_trinh(tieu_de: str, thoi_gian_bat_dau: str, thoi_gian_ket_thuc: str, user_id: str) -> str:
    """
    Tạo một LỊCH TRÌNH (schedule) MỚI.
    Dùng khi người dùng nói 'đặt lịch', 'thêm lịch hẹn', 'tạo sự kiện'.
    Hàm này sẽ tự động tạo một CÔNG VIỆC (task) và một LỊCH TRÌNH (schedule) liên kết với nhau.
    """
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                # 1. Tạo task trước
                task_query = text("""
                    INSERT INTO tasks (user_id, title, status) 
                    VALUES (:user_id, :title, 'todo') 
                    RETURNING id;
                """)
                result = connection.execute(task_query, {"user_id": user_id, "title": tieu_de})
                task_id = result.scalar_one_or_none()
                if not task_id:
                    raise Exception("Không thể tạo task liên kết.")

                # 2. Tạo schedule liên kết với task_id
                schedule_query = text("""
                    INSERT INTO schedules (user_id, task_id, start_time, end_time) 
                    VALUES (:user_id, :task_id, :start_time, :end_time);
                """)
                connection.execute(
                    schedule_query,
                    {
                        "user_id": user_id,
                        "task_id": task_id,
                        "start_time": thoi_gian_bat_dau,
                        "end_time": thoi_gian_ket_thuc
                    }
                )
                transaction.commit()
                return f"✅ Đã lên lịch '{tieu_de}' lúc {thoi_gian_bat_dau}."
    except Exception as e:
        return f"❌ Lỗi khi tạo lịch trình: {e}"

@tool
def tao_ghi_chu(noi_dung: str, user_id: str, task_tieu_de: str | None = None) -> str:
    """
    Tạo một GHI CHÚ (note) mới.
    Nếu `task_tieu_de` được cung cấp, ghi chú sẽ được liên kết với công việc đó.
    Nếu không, ghi chú sẽ được tạo độc lập.
    """
    try:
        task_id = None
        with engine.connect() as connection:
            with connection.begin() as transaction:
                if task_tieu_de:
                    task_id = _get_task_id_from_title(connection, user_id, task_tieu_de)
                    if not task_id:
                        return f"⚠️ Không tìm thấy công việc '{task_tieu_de}' để đính kèm ghi chú."

                query = text("""
                    INSERT INTO notes (user_id, content, task_id) 
                    VALUES (:user_id, :content, :task_id);
                """)
                connection.execute(query, {"user_id": user_id, "content": noi_dung, "task_id": task_id})
                transaction.commit()
                
                if task_id:
                    return f"✅ Đã tạo ghi chú và đính kèm vào công việc '{task_tieu_de}'."
                else:
                    return f"✅ Đã tạo ghi chú mới."
    except Exception as e:
        return f"❌ Lỗi khi tạo ghi chú: {e}"

@tool
def them_muc_vao_checklist(task_tieu_de: str, noi_dung_muc: str, user_id: str) -> str:
    """Thêm một mục (item) mới vào CHECKLIST của một CÔNG VIỆC (task) đã có."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                task_id = _get_task_id_from_title(connection, user_id, task_tieu_de)
                if not task_id:
                    return f"⚠️ Không tìm thấy công việc '{task_tieu_de}' để thêm checklist."
                
                query = text("""
                    INSERT INTO checklist_items (task_id, content, is_checked)
                    VALUES (:task_id, :content, FALSE);
                """)
                connection.execute(query, {"task_id": task_id, "content": noi_dung_muc})
                transaction.commit()
                return f"✅ Đã thêm '{noi_dung_muc}' vào checklist của công việc '{task_tieu_de}'."
    except Exception as e:
        return f"❌ Lỗi khi thêm checklist: {e}"

@tool
def xoa_task_hoac_lich_trinh(tieu_de: str, user_id: str) -> str:
    """
    Xóa một CÔNG VIỆC (task) hoặc LỊCH TRÌNH (schedule) dựa trên tiêu đề.
    Do CSDL thiết kế ON DELETE CASCADE, xóa task sẽ tự động xóa schedule, checklist, reminder liên quan.
    """
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                task_id = _get_task_id_from_title(connection, user_id, tieu_de)
                if not task_id:
                    return f"⚠️ Không tìm thấy '{tieu_de}' để xóa."

                query = text("DELETE FROM tasks WHERE id = :task_id;")
                result = connection.execute(query, {"task_id": task_id})
                transaction.commit()
                
                if result.rowcount > 0:
                    return f"🗑️ Đã xóa thành công '{tieu_de}' và tất cả dữ liệu liên quan."
                else:
                    return f"⚠️ Không thể xóa '{tieu_de}'."
    except Exception as e:
        return f"❌ Lỗi khi xóa: {e}"

@tool
def tim_lich_trinh(ngay_bat_dau: str, ngay_ket_thuc: str, user_id: str) -> str:
    """Tìm các lịch trình trong một khoảng ngày được chỉ định cho một user cụ thể."""
    try:
        with engine.connect() as connection:
            query = text("""
                SELECT t.title, s.start_time 
                FROM schedules s 
                JOIN tasks t ON s.task_id = t.id 
                WHERE s.user_id = :user_id 
                AND s.start_time::date BETWEEN :start_date AND :end_date 
                ORDER BY s.start_time LIMIT 10;
            """)
            results = connection.execute(query, {"user_id": user_id, "start_date": ngay_bat_dau, "end_date": ngay_ket_thuc}).fetchall()
            if not results:
                return f"📭 Bạn không có lịch trình nào từ {ngay_bat_dau} đến {ngay_ket_thuc}."
            events = [f"- '{row.title}' lúc {row.start_time.strftime('%H:%M ngày %d/%m/%Y')}" for row in results]
            return f"🔎 Bạn có {len(events)} lịch trình:\n" + "\n".join(events)
    except Exception as e:
        return f"❌ Lỗi khi tìm lịch: {e}"

@tool
def doi_lich_trinh(tieu_de_cu: str, thoi_gian_moi: str, user_id: str) -> str:
    """Chỉnh sửa thời gian của một LỊCH TRÌNH (schedule) đã có."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                find_query = text("""
                    SELECT t.id, s.start_time 
                    FROM tasks t 
                    JOIN schedules s ON t.id = s.task_id 
                    WHERE t.user_id = :user_id AND unaccent(t.title) ILIKE unaccent(:title_like)
                    ORDER BY t.is_completed ASC, s.start_time DESC
                    LIMIT 1;
                """)
                original_task = connection.execute(find_query, {"user_id": user_id, "title_like": f"%{tieu_de_cu}%"}).fetchone()
                
                if not original_task:
                    return f"⚠️ Không tìm thấy lịch trình '{tieu_de_cu}' để dời."

                task_id, old_start_time = original_task.id, original_task.start_time
                new_start, new_end = parse_natural_time(thoi_gian_moi, base_date=old_start_time)

                update_query = text("UPDATE schedules SET start_time = :start_time, end_time = :end_time WHERE task_id = :task_id;")
                result = connection.execute(update_query, {"start_time": new_start, "end_time": new_end, "task_id": task_id})
                transaction.commit()

                if result.rowcount > 0:
                    return f"✅ Đã dời '{tieu_de_cu}' sang {new_start.strftime('%H:%M %d/%m/%Y')}."
                else:
                    return f"⚠️ Không thể cập nhật '{tieu_de_cu}'."
    except Exception as e:
        return f"❌ Lỗi khi chỉnh sửa: {e}"

@tool
def danh_dau_task_hoan_thanh(tieu_de: str, user_id: str) -> str:
    """Đánh dấu một CÔNG VIỆC (task) là đã hoàn thành (is_completed = TRUE)."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                task_id = _get_task_id_from_title(connection, user_id, tieu_de)
                if not task_id:
                    return f"🤔 Không tìm thấy công việc nào có tên '{tieu_de}' để đánh dấu."

                query = text("UPDATE tasks SET is_completed = TRUE, status = 'done' WHERE id = :task_id;")
                result = connection.execute(query, {"task_id": task_id})
                transaction.commit()

                if result.rowcount > 0:
                    return f"👍 Rất tốt! Đã đánh dấu '{tieu_de}' là đã hoàn thành."
                else:
                    return f"⚠️ Không thể cập nhật '{tieu_de}'."
    except Exception as e:
        return f"❌ Lỗi khi đánh dấu hoàn thành: {e}"

@tool
def gan_the_vao_task(task_tieu_de: str, ten_the: str, user_id: str) -> str:
    """Gắn một THẺ (tag) vào một CÔNG VIỆC (task) đã có."""
    try:
        with engine.connect() as connection:
            with connection.begin() as transaction:
                task_id = _get_task_id_from_title(connection, user_id, task_tieu_de)
                if not task_id:
                    return f"⚠️ Không tìm thấy công việc '{task_tieu_de}' để gắn thẻ."

                # Tìm hoặc tạo thẻ (tag)
                tag_query = text("""
                    INSERT INTO tags (user_id, name) 
                    VALUES (:user_id, :name) 
                    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name 
                    RETURNING id;
                """)
                tag_id = connection.execute(tag_query, {"user_id": user_id, "name": ten_the}).scalar_one()

                # Gắn thẻ vào task
                task_tag_query = text("""
                    INSERT INTO task_tags (task_id, tag_id)
                    VALUES (:task_id, :tag_id)
                    ON CONFLICT (task_id, tag_id) DO NOTHING;
                """)
                connection.execute(task_tag_query, {"task_id": task_id, "tag_id": tag_id})
                transaction.commit()
                return f"✅ Đã gắn thẻ '{ten_the}' cho công việc '{task_tieu_de}'."
    except Exception as e:
        return f"❌ Lỗi khi gắn thẻ: {e}"

@tool
def tom_tat_tien_do(user_id: str) -> str:
    """Cung cấp tóm tắt về lịch trình và công việc của người dùng. Dùng khi người dùng hỏi chung chung."""
    try:
        with engine.connect() as connection:
            total_query = text("SELECT COUNT(*) FROM tasks WHERE user_id = :user_id;")
            total_tasks = connection.execute(total_query, {"user_id": user_id}).scalar_one()

            completed_query = text("SELECT COUNT(*) FROM tasks WHERE user_id = :user_id AND is_completed = TRUE;")
            completed_tasks = connection.execute(completed_query, {"user_id": user_id}).scalar_one()
            
            todo_tasks = total_tasks - completed_tasks

            upcoming_query = text("""
                SELECT t.title, s.start_time 
                FROM schedules s 
                JOIN tasks t ON s.task_id = t.id 
                WHERE s.user_id = :user_id AND s.start_time > NOW() AND t.is_completed = FALSE 
                ORDER BY s.start_time ASC LIMIT 3;
            """)
            upcoming_results = connection.execute(upcoming_query, {"user_id": user_id}).fetchall()

            summary = f"Tổng quan của bạn:\n- 📊 Bạn có tổng cộng {total_tasks} công việc.\n- ✅ {completed_tasks} đã hoàn thành.\n- ⏳ {todo_tasks} chưa hoàn thành.\n"
            if upcoming_results:
                summary += "- 🗓️ Các lịch trình chưa hoàn thành sắp tới:\n" + "\n".join([f"  - '{row.title}' lúc {row.start_time.strftime('%H:%M %d/%m')}" for row in upcoming_results])
            else:
                summary += "- 🗓️ Bạn không có lịch trình nào sắp tới hoặc tất cả đều đã hoàn thành."
            return summary
    except Exception as e:
        return f"❌ Lỗi khi tóm tắt: {e}"

# --- 6. LẮP RÁP AGENT & BỘ NHỚ ---
tools_list = [
    lay_ten_nguoi_dung,
    tao_lich_trinh,
    tao_task_don_le,
    tao_ghi_chu,
    them_muc_vao_checklist,
    gan_the_vao_task,
    xoa_task_hoac_lich_trinh,
    tim_lich_trinh,
    doi_lich_trinh,
    danh_dau_task_hoan_thanh,
    tom_tat_tien_do
]

today = date.today()
system_prompt_template = f"""
Bạn là một trợ lý AI quản lý công việc và lịch trình cá nhân tên là Skedule.
BỐI CẢNH: Hôm nay là {today.strftime('%A, %d/%m/%Y')}.
QUY TẮC NGHIỆP VỤ (Rất quan trọng):
1.  **Phân biệt rõ ràng:**
    * 'Lịch trình', 'lịch hẹn', 'sự kiện' (ví dụ: "hẹn bác sĩ lúc 5h") => Dùng tool `tao_lich_trinh`. Cần có thời gian bắt đầu và kết thúc.
    * 'Công việc', 'task', 'nhiệm vụ', 'deadline' (ví dụ: "tạo task nộp bài tập") => Dùng tool `tao_task_don_le`. Không nhất thiết cần giờ cụ thể.
    * 'Ghi chú', 'note', 'lưu lại' (ví dụ: "lưu ý tưởng này") => Dùng tool `tao_ghi_chu`.
    * 'Thêm mục', 'checklist' (ví dụ: "thêm 'mua sữa' vào task 'đi chợ'") => Dùng tool `them_muc_vao_checklist`.
    * 'Gắn thẻ', 'tag' (ví dụ: "gắn thẻ 'ưu tiên' cho task 'làm slide'") => Dùng tool `gan_the_vao_task`.
    * 'Xong', 'hoàn thành' (ví dụ: "đánh dấu 'làm slide' là xong") => Dùng tool `danh_dau_task_hoan_thanh`.
    * 'Xóa', 'hủy' (ví dụ: "xóa lịch họp 5h") => Dùng tool `xoa_task_hoac_lich_trinh`.
    * 'Dời', 'đổi' (ví dụ: "dời lịch họp sang 6h") => Dùng tool `doi_lich_trinh`.
    * 'Tìm', 'có gì' (ví dụ: "ngày mai tôi có gì") => Dùng tool `tim_lich_trinh`.

2.  **Luôn gọi tool:** Luôn sử dụng các công cụ (tools) để thực hiện các yêu cầu trên.
3.  **Chào hỏi:** Khi bắt đầu cuộc trò chuyện hoặc khi chào hỏi, hãy luôn thử gọi tool `lay_ten_nguoi_dung` trước tiên.
4.  **Sử dụng user_id:** Luôn sử dụng `user_id` được cung cấp trong prompt để gọi tool.
5.  **Định dạng ngày:** Khi gọi tool `tim_lich_trinh`, BẮT BUỘC phải truyền ngày tháng theo định dạng 'YYYY-MM-DD'.
6.  **Diễn giải kết quả:** Sau khi tool chạy xong, hãy diễn giải kết quả đó (ví dụ: "✅ Đã tạo...") thành một câu trả lời tự nhiên, đầy đủ và lịch sự cho người dùng.
"""
prompt = ChatPromptTemplate.from_messages([
    ("system", system_prompt_template),
    MessagesPlaceholder(variable_name="chat_history"),
    ("human", "USER_ID: {user_id}\n\nPROMPT: {input}"),
    MessagesPlaceholder(variable_name="agent_scratchpad"),
])
agent = create_tool_calling_agent(llm_brain, tools_list, prompt)
agent_executor = AgentExecutor(agent=agent, tools=tools_list, verbose=True)
store = {}
def get_session_history(session_id: str) -> BaseChatMessageHistory:
    if session_id not in store:
        store[session_id] = ChatMessageHistory()
    return store[session_id]
agent_with_chat_history = RunnableWithMessageHistory(
    agent_executor, get_session_history,
    input_messages_key="input",
    history_messages_key="chat_history",
    input_messages_and_history_passthrough=True,
)

# --- 7. API SERVER ---
app = FastAPI(title="Skedule AI Agent API", version="3.0.0 (Full SRS)")

class ChatResponse(BaseModel):
    user_prompt: str | None = None
    text_response: str
    audio_base64: str

@app.get("/")
def read_root():
    return {"message": "Skedule AI Agent (Full SRS) is running!"}

# Include Payment Router
app.include_router(payment_router)

@app.post("/chat", response_model=ChatResponse)
async def handle_chat_request(
    prompt: str | None = Form(None),
    audio_file: UploadFile | None = File(None),
    user_id: str = Depends(get_current_user_id)
):
    user_prompt = ""
    if audio_file:
        user_prompt = await audio_to_text(audio_file)
    elif prompt:
        user_prompt = prompt
    else:
        raise HTTPException(status_code=400, detail="Cần cung cấp prompt dạng văn bản hoặc file âm thanh.")

    session_id = f"user_{user_id}"
    logger.info(f"📨 Prompt nhận từ user {user_id}: {user_prompt}")

    final_result = agent_with_chat_history.invoke(
        {"input": user_prompt, "user_id": user_id},
        config={"configurable": {"session_id": session_id}}
    )
    ai_text_response = final_result.get("output", "Lỗi: Không có phản hồi từ agent.")

    ai_audio_base64 = text_to_base64_audio(ai_text_response)

    return ChatResponse(
        user_prompt=user_prompt if audio_file else None,
        text_response=ai_text_response,
        audio_base64=ai_audio_base64
    )
