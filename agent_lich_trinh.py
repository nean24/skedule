from dotenv import load_dotenv
import os
import io
import base64
import logging
from datetime import date, datetime, timedelta
from typing import Optional, List

from fastapi import FastAPI, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy import text
from gtts import gTTS
import speech_recognition as sr
from pydub import AudioSegment

# Import LangChain & Google GenAI
try:
    from langchain.agents import AgentExecutor, create_tool_calling_agent
except ImportError:
    from langchain.agents.agent import AgentExecutor
    from langchain.agents import create_tool_calling_agent

from langchain.tools import tool
from langchain_core.chat_history import BaseChatMessageHistory
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.runnables.history import RunnableWithMessageHistory
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.chat_message_histories import ChatMessageHistory

from utils.thoi_gian_tu_nhien import parse_natural_time
from app_dependencies import get_current_user_id, engine

# --- 1. CẤU HÌNH ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Sử dụng model Flash Latest cho tốc độ và hiệu năng tốt nhất
llm_brain = ChatGoogleGenerativeAI(
    # <--- Dùng tên CHÍNH XÁC này (đừng dùng 2.5 hay 2.0)
    model="gemini-2.5-flash",
    google_api_key=GEMINI_API_KEY,
    temperature=0.6,
    # Thêm dòng này để tránh lỗi nếu Google đổi version ngầm
    transport="rest"
)

# --- 2. XỬ LÝ ÂM THANH ---
def clean_text_for_speech(text: str) -> str:
    # Loại bỏ các ký tự markdown để giọng đọc tự nhiên hơn
    return text.replace('*', '').replace('#', '').replace('-', ' ').replace('_', '')

def text_to_base64_audio(text: str) -> str:
    try:
        if not text:
            return ""
        # Chỉ đọc 200 ký tự đầu để tránh chờ lâu nếu phản hồi quá dài
        short_text = clean_text_for_speech(text)[:200]
        tts = gTTS(short_text, lang='vi')
        audio_fp = io.BytesIO()
        tts.write_to_fp(audio_fp)
        audio_fp.seek(0)
        return base64.b64encode(audio_fp.read()).decode('utf-8')
    except Exception as e:
        logger.error(f"Lỗi TTS: {e}")
        return ""

async def audio_to_text(audio_file: UploadFile) -> str:
    try:
        r = sr.Recognizer()
        audio_bytes = await audio_file.read()
        audio_fp = io.BytesIO(audio_bytes)
        sound = AudioSegment.from_file(audio_fp)
        wav_fp = io.BytesIO()
        sound.export(wav_fp, format="wav")
        wav_fp.seek(0)
        with sr.AudioFile(wav_fp) as source:
            audio_data = r.record(source)
            return r.recognize_google(audio_data, language="vi-VN")
    except Exception as e:
        logger.error(f"Lỗi STT: {e}")
        return ""

# --- 3. CÁC CÔNG CỤ (TOOLS) THÔNG MINH ---

@tool
def lay_ten_nguoi_dung(user_id: str) -> str:
    """Lấy thông tin profile và thống kê nhanh trạng thái công việc của user."""
    try:
        with engine.connect() as connection:
            # Lấy Profile
            profile = connection.execute(
                text("SELECT name, email FROM public.profiles WHERE id = :uid"),
                {"uid": user_id}
            ).fetchone()

            if not profile or not profile.name:
                return "Chào bạn mới! Tôi là Skedule AI."

            # Thống kê nhanh để AI nắm tình hình
            stats = connection.execute(text("""
                SELECT 
                    COUNT(*) FILTER (WHERE status = 'todo') as todo,
                    COUNT(*) FILTER (WHERE deadline < NOW() AND status != 'done') as overdue
                FROM tasks WHERE user_id = :uid
            """), {"uid": user_id}).fetchone()

            return (
                f"User: {profile.name} ({profile.email}). "
                f"Status: {stats.todo} việc cần làm, {stats.overdue} việc quá hạn. "
                "Hãy hỏi user cần giúp gì."
            )
    except Exception as e:
        return f"Lỗi lấy thông tin: {e}"


@tool
def lay_lich_trinh_tuan(user_id: str, start_date: Optional[str] = None) -> str:
    """
    Lấy danh sách sự kiện trong 7 ngày tới để phân tích, gợi ý sắp xếp hoặc kiểm tra rảnh bận.
    Dùng khi user hỏi: "Tuần này tôi bận không?", "Gợi ý lịch học", "Tối ưu lịch".
    """
    try:
        with engine.connect() as conn:
            # Mặc định lấy từ hôm nay
            s_date = datetime.now()
            if start_date:
                s_date, _ = parse_natural_time(start_date, datetime.now())

            e_date = s_date + timedelta(days=7)

            query = text("""
                SELECT title, type, start_time, end_time 
                FROM events 
                WHERE user_id = :uid 
                AND start_time >= :start AND start_time <= :end
                ORDER BY start_time ASC
            """)
            rows = conn.execute(
                query, {"uid": user_id, "start": s_date, "end": e_date}).fetchall()

            if not rows:
                return "Lịch trình trống trong 7 ngày tới. Rất thích hợp để lên kế hoạch mới!"

            data = "\n".join(
                [f"- [{row.type}] {row.title}: {row.start_time.strftime('%H:%M %d/%m')} - {row.end_time.strftime('%H:%M') if row.end_time else '...'}" for row in rows])
            return f"Dữ liệu lịch trình (để AI phân tích):\n{data}"
    except Exception as e:
        return f"Lỗi lấy lịch: {e}"

@tool
def tao_su_kien_toan_dien(tieu_de: str, loai_su_kien: str, user_id: str, mo_ta: Optional[str] = None,
                         bat_dau: Optional[str] = None, ket_thuc: Optional[str] = None,
                         uu_tien: str = 'medium') -> str:
    """
    Tạo sự kiện/task. TỰ ĐỘNG CẢNH BÁO nếu trùng giờ.
    loai_su_kien: task, schedule, class, workshift, deadline.
    uu_tien: cao, trung bình, thấp.
    """
    try:
        with engine.connect() as conn:
            with conn.begin():
                now = datetime.now()
                start_dt, end_dt = None, None

                # 1. XỬ LÝ THỜI GIAN
                if bat_dau:
                    start_dt, temp_end = parse_natural_time(bat_dau, now)
                    if temp_end and not end_dt:
                        end_dt = temp_end
                if ket_thuc:
                    _, end_dt = parse_natural_time(ket_thuc, start_dt or now)

                if start_dt and not end_dt and loai_su_kien != 'deadline':
                    end_dt = start_dt + timedelta(hours=1)

                # 2. XỬ LÝ MAPPING (QUAN TRỌNG: VIỆT -> ANH)
                # Map từ tiếng Việt sang ENUM của Postgres ('high', 'medium', 'low')
                priority_map = {
                    'cao': 'high', 'khẩn cấp': 'high', 'gấp': 'high', 'high': 'high',
                    'trung bình': 'medium', 'bình thường': 'medium', 'medium': 'medium',
                    'thấp': 'low', 'low': 'low'
                }
                # Mặc định là medium nếu không khớp
                db_priority = priority_map.get(uu_tien.lower(), 'medium')

                # 3. KIỂM TRA XUNG ĐỘT
                warning_msg = ""
                if start_dt and end_dt:
                    conflict = conn.execute(text("""
                        SELECT title FROM events 
                        WHERE user_id = :uid 
                        AND id != 0
                        AND type != 'deadline'
                        AND (start_time < :end AND end_time > :start)
                    """), {"uid": user_id, "start": start_dt, "end": end_dt}).fetchone()

                    if conflict:
                        warning_msg = f"\n⚠️ LƯU Ý: Sự kiện này trùng giờ với '{conflict.title}'!"

                # 4. TẠO EVENT
                event_id = conn.execute(text("""
                    INSERT INTO events (user_id, title, description, type, start_time, end_time)
                    VALUES (:uid, :title, :desc, :type, :start, :end) RETURNING id
                """), {
                    "uid": user_id, "title": tieu_de, "desc": mo_ta,
                    "type": loai_su_kien, "start": start_dt, "end": end_dt
                }).scalar()

                # 5. TẠO TASK (Với priority đã được map sang tiếng Anh)
                task_id = conn.execute(text("""
                    INSERT INTO tasks (user_id, event_id, title, description, deadline, priority, status)
                    VALUES (:uid, :eid, :title, :desc, :dl, :pri, 'todo') RETURNING id
                """), {
                    "uid": user_id, "eid": event_id, "title": tieu_de,
                    "desc": mo_ta, "dl": end_dt or start_dt,
                    "pri": db_priority  # <--- Dùng biến đã sửa ở đây
                }).scalar()

                # 6. TẠO SCHEDULE (Nếu cần)
                if start_dt and loai_su_kien != 'deadline':
                    conn.execute(text("""
                        INSERT INTO schedules (user_id, task_id, event_id, start_time, end_time)
                        VALUES (:uid, :tid, :eid, :start, :end)
                    """), {
                        "uid": user_id, "tid": task_id, "eid": event_id,
                        "start": start_dt, "end": end_dt
                    })

                return f"✅ Đã tạo {loai_su_kien}: '{tieu_de}' (Ưu tiên: {db_priority}).{warning_msg}"
    except Exception as e:
        return f"❌ Lỗi: {e}"

@tool
def cap_nhat_su_kien(tieu_de_cu: str, thoi_gian_moi: str, user_id: str) -> str:
    """Dùng khi user muốn 'dời lịch', 'sắp xếp lại', 'đổi giờ'."""
    try:
        with engine.connect() as conn:
            with conn.begin():
                # Tìm event
                event = conn.execute(text("SELECT id, start_time FROM events WHERE user_id = :uid AND title ILIKE :t LIMIT 1"),
                                     {"uid": user_id, "t": f"%{tieu_de_cu}%"}).fetchone()
                if not event:
                    return "⚠️ Không tìm thấy sự kiện để dời."

                # Tính giờ mới
                new_start, new_end = parse_natural_time(
                    thoi_gian_moi, datetime.now())
                if not new_end:
                    new_end = new_start + timedelta(hours=1)

                # Update
                conn.execute(text("""
                    UPDATE events SET start_time = :s, end_time = :e, updated_at = NOW() 
                    WHERE id = :id
                """), {"s": new_start, "e": new_end, "id": event.id})

                # Update các bảng con (Cascade thường không tự update time, nên làm thủ công cho chắc)
                conn.execute(text("UPDATE schedules SET start_time=:s, end_time=:e WHERE event_id=:id"),
                             {"s": new_start, "e": new_end, "id": event.id})

                return f"✅ Đã dời '{tieu_de_cu}' sang {new_start}."
    except Exception as e:
        return f"Lỗi update: {e}"


@tool
def tao_ghi_chu_thong_minh(noi_dung: str, user_id: str, context_title: Optional[str] = None) -> str:
    """Tạo ghi chú (Note)."""
    try:
        with engine.connect() as conn:
            with conn.begin():
                event_id = None
                if context_title:
                    event_id = conn.execute(text("SELECT id FROM events WHERE user_id = :uid AND title ILIKE :t LIMIT 1"),
                                            {"uid": user_id, "t": f"%{context_title}%"}).scalar()
                conn.execute(text("INSERT INTO notes (user_id, content, event_id) VALUES (:uid, :content, :eid)"),
                             {"uid": user_id, "content": noi_dung, "eid": event_id})
            return "✅ Đã lưu ghi chú."
    except Exception as e:
        return f"Lỗi: {e}"

@tool
def xoa_su_kien_toan_tap(tieu_de: str, user_id: str) -> str:
    """Xóa sự kiện/task."""
    try:
        with engine.connect() as conn:
            res = conn.execute(text("DELETE FROM events WHERE user_id = :uid AND title ILIKE :t"),
                               {"uid": user_id, "t": f"%{tieu_de}%"})
            conn.commit()
            return f"🗑️ Đã xóa '{tieu_de}'." if res.rowcount > 0 else "⚠️ Không tìm thấy sự kiện."
    except Exception as e:
        return f"Lỗi xóa: {e}"


@tool
def thong_ke_tong_quan(user_id: str) -> str:
    """
    Đếm số lượng: Task (cần làm/đã xong), Ghi chú, Sự kiện trong tuần.
    Dùng khi user hỏi: "Tổng quan", "Tôi có bao nhiêu việc", "Báo cáo tiến độ".
    """
    try:
        with engine.connect() as conn:
            # 1. Đếm Task theo trạng thái
            task_stats = conn.execute(text("""
                SELECT 
                    COUNT(*) FILTER (WHERE status = 'todo') as todo,
                    COUNT(*) FILTER (WHERE status = 'in_progress') as doing,
                    COUNT(*) FILTER (WHERE status = 'done') as done
                FROM tasks WHERE user_id = :uid
            """), {"uid": user_id}).fetchone()

            # 2. Đếm Note
            note_count = conn.execute(text("SELECT COUNT(*) FROM notes WHERE user_id = :uid"),
                                      {"uid": user_id}).scalar()

            # 3. Đếm Sự kiện tuần này
            event_count = conn.execute(text("""
                SELECT COUNT(*) FROM events 
                WHERE user_id = :uid 
                AND start_time >= CURRENT_DATE 
                AND start_time < CURRENT_DATE + INTERVAL '7 days'
            """), {"uid": user_id}).scalar()

            return (
                f"📊 BÁO CÁO TỔNG QUAN:\n"
                f"- Công việc: {task_stats.todo} cần làm, {task_stats.doing} đang làm, {task_stats.done} đã xong.\n"
                f"- Ghi chú: {note_count} ghi chú đã lưu.\n"
                f"- Lịch trình: {event_count} sự kiện trong 7 ngày tới."
            )
    except Exception as e:
        return f"Lỗi thống kê: {e}"


@tool
def liet_ke_danh_sach(user_id: str, loai: str = 'all', gioi_han: int = 5) -> str:
    """
    Liệt kê danh sách. Tự động chọn bảng 'notes' hoặc 'events' tùy theo yêu cầu.
    """
    try:
        with engine.connect() as conn:
            # TRƯỜNG HỢP 1: LIỆT KÊ GHI CHÚ (Query bảng notes)
            if loai in ['ghi chú', 'note']:
                query = text("""
                    SELECT content, created_at 
                    FROM notes 
                    WHERE user_id = :uid 
                    ORDER BY created_at DESC 
                    LIMIT :limit
                """)
                rows = conn.execute(
                    query, {"uid": user_id, "limit": gioi_han}).fetchall()

                if not rows:
                    return "📭 Bạn chưa có ghi chú nào."

                result = f"📝 DANH SÁCH GHI CHÚ ({len(rows)} mục mới nhất):\n"
                for row in rows:
                    date_str = row.created_at.strftime(
                        '%d/%m') if row.created_at else ""
                    # Lấy 50 ký tự đầu làm tiêu đề
                    preview = row.content.split('\n')[0][:50]
                    result += f"- [{date_str}] {preview}...\n"
                return result

            # TRƯỜNG HỢP 2: LIỆT KÊ SỰ KIỆN/TASK (Query bảng events)
            else:
                base_query = "SELECT title, type, start_time, description FROM events WHERE user_id = :uid"

                # Lọc theo loại task/deadline/schedule
                if loai not in ['all', 'tất cả']:
                    # Map loại
                    if loai in ['công việc', 'task']:
                        db_type = 'task'
                    elif loai in ['hạn', 'deadline']:
                        db_type = 'deadline'
                    elif loai in ['lịch', 'schedule']:
                        db_type = 'schedule'
                    else:
                        db_type = loai  # Mặc định

                    base_query += f" AND type = '{db_type}'"

                # Sắp xếp
                query = text(
                    base_query + " ORDER BY start_time ASC NULLS LAST LIMIT :limit")
                rows = conn.execute(
                    query, {"uid": user_id, "limit": gioi_han}).fetchall()

                if not rows:
                    return f"📭 Không tìm thấy mục nào thuộc loại '{loai}'."

                result = f"📋 DANH SÁCH {loai.upper()} ({len(rows)} mục):\n"
                for row in rows:
                    time_str = row.start_time.strftime(
                        '%d/%m %H:%M') if row.start_time else "---"
                    result += f"- [{row.type}] **{row.title}** ({time_str})\n"
                return result

    except Exception as e:
        return f"Lỗi liệt kê: {e}"


@tool
def xem_chi_tiet_su_kien(user_id: str, tu_khoa: str) -> str:
    """
    Tìm kiếm thông minh (Full Text Search) trong cả EVENT và NOTE.
    Chấp nhận từ khóa không cần chính xác tuyệt đối (VD: 'ý tưởng giao diện' vẫn tìm ra 'ý tưởng làm giao diện').
    """
    try:
        with engine.connect() as conn:
            # --- KỸ THUẬT: Dùng to_tsvector @@ plainto_tsquery ---
            # Hàm này sẽ tách 'ý tưởng giao diện' thành: tìm 'ý' VÀ 'tưởng' VÀ 'giao' VÀ 'diện'
            # Bất kể các từ này nằm cách xa nhau bao nhiêu trong câu.

            search_condition = """
                (
                    title ILIKE :kw_like              -- Cách 1: Tìm chính xác (như cũ)
                    OR 
                    to_tsvector('simple', title) @@ plainto_tsquery('simple', :kw_plain) -- Cách 2: Tìm theo từ khóa
                )
            """

            # 1. Tìm trong bảng EVENTS
            event = conn.execute(text(f"""
                SELECT id, title, description, type, start_time, end_time 
                FROM events 
                WHERE user_id = :uid 
                AND {search_condition}
                LIMIT 1
            """), {
                "uid": user_id,
                "kw_like": f"%{tu_khoa}%",
                "kw_plain": tu_khoa
            }).fetchone()

            if event:
                details = (
                    f"🔎 CHI TIẾT SỰ KIỆN: {event.title.upper()}\n"
                    f"- Loại: {event.type}\n"
                    f"- Thời gian: {event.start_time} -> {event.end_time}\n"
                    f"- Mô tả: {event.description or 'Không có'}\n"
                )

                if event.type in ['task', 'deadline']:
                    task = conn.execute(text("SELECT priority, status, deadline FROM tasks WHERE event_id = :eid"), {
                                        "eid": event.id}).fetchone()
                    if task:
                        details += f"- Ưu tiên: {task.priority} | Trạng thái: {task.status}\n"

                    checklists = conn.execute(text("SELECT item_text, is_done FROM checklist_items WHERE task_id = (SELECT id FROM tasks WHERE event_id = :eid)"), {
                                              "eid": event.id}).fetchall()
                    if checklists:
                        details += "- Checklist:\n" + \
                            "\n".join(
                                [f"  [{'x' if c.is_done else ' '}] {c.item_text}" for c in checklists])

                return details

            # 2. Tìm trong bảng NOTES (Áp dụng logic tương tự cho cột content)
            note_condition = """
                (
                    content ILIKE :kw_like 
                    OR 
                    to_tsvector('simple', content) @@ plainto_tsquery('simple', :kw_plain)
                )
            """

            note = conn.execute(text(f"""
                SELECT content, created_at 
                FROM notes 
                WHERE user_id = :uid 
                AND {note_condition}
                LIMIT 1
            """), {
                "uid": user_id,
                "kw_like": f"%{tu_khoa}%",
                "kw_plain": tu_khoa
            }).fetchone()

            if note:
                return f"📝 CHI TIẾT GHI CHÚ (Ngày tạo: {note.created_at.strftime('%d/%m/%Y') if note.created_at else 'N/A'}):\n\n{note.content}"

            return f"⚠️ Không tìm thấy Sự kiện hay Ghi chú nào khớp với '{tu_khoa}'."

    except Exception as e:
        return f"Lỗi tìm kiếm: {e}"
# --- 4. CẤU HÌNH AGENT & PROMPT ---


# --- CẬP NHẬT LIST TOOLS ---
tools = [
    lay_ten_nguoi_dung,
    tao_su_kien_toan_dien,
    lay_lich_trinh_tuan,
    cap_nhat_su_kien,
    tao_ghi_chu_thong_minh,
    xoa_su_kien_toan_tap,
    # Thêm 3 tool mới:
    thong_ke_tong_quan,
    liet_ke_danh_sach,
    xem_chi_tiet_su_kien
]

# --- CẬP NHẬT SYSTEM PROMPT ---
system_prompt = f"""
Bạn là Skedule AI - Trợ lý quản lý cuộc sống toàn năng.
Hôm nay: {date.today().strftime('%A, %d/%m/%Y')}.

KHẢ NĂNG CỦA BẠN:
1. 📊 Báo cáo: Đếm số lượng task, note, sự kiện (dùng `thong_ke_tong_quan`).
2. 📋 Liệt kê: Hiện danh sách note, task, deadline (dùng `liet_ke_danh_sach`).
3. 🔎 Soi chi tiết: Xem kỹ nội dung của 1 mục cụ thể (dùng `xem_chi_tiet_su_kien`).
4. 📅 Quản lý & Gợi ý: Tạo/Sửa/Xóa lịch và gợi ý Work-Life Balance.

QUY TẮC PHẢN HỒI:
(BẮT BUỘC):
1. SAU KHI GỌI TOOL: Bạn KHÔNG ĐƯỢC im lặng. 
2. Bạn phải nhắc lại kết quả mà tool trả về.
   - Ví dụ: Nếu tool trả về "✅ Đã tạo task A", bạn phải đáp lại user: "✅ Đã tạo task A".
3. KHÔNG BAO GIỜ trả về câu trả lời rỗng.
4. Khi user hỏi "Tôi có bao nhiêu...", "Tổng kết...", hãy dùng `thong_ke_tong_quan`.
5. Khi user hỏi "Danh sách note", "Liệt kê task", hãy dùng `liet_ke_danh_sach`.
6. Khi user hỏi "Xem chi tiết [tên]", "Nội dung của [tên]", hãy dùng `xem_chi_tiet_su_kien`.
7. Luôn trả lời ngắn gọn, format đẹp mắt, không sử dụng dấu ** vì trông rất xấu.
"""

prompt_template = ChatPromptTemplate.from_messages([
    ("system", system_prompt),
    MessagesPlaceholder(variable_name="chat_history"),
    ("human", "USER_ID: {user_id}\nPROMPT: {input}"),
    MessagesPlaceholder(variable_name="agent_scratchpad"),
])

agent_executor = AgentExecutor(
    agent=create_tool_calling_agent(llm_brain, tools, prompt_template),
    tools=tools,
    verbose=True
)

store = {}

def get_history(session_id: str) -> BaseChatMessageHistory:
    if session_id not in store: store[session_id] = ChatMessageHistory()
    return store[session_id]


agent_with_history = RunnableWithMessageHistory(
    agent_executor, get_history, input_messages_key="input", history_messages_key="chat_history"
)

# --- 5. API ENDPOINT ---
app = FastAPI(title="Skedule AI Agent v2.0 (Optimized)")

@app.post("/chat")
async def chat(prompt: Optional[str] = Form(None), audio_file: Optional[UploadFile] = File(None), user_id: str = Depends(get_current_user_id)):
    user_prompt = ""
    if audio_file:
        user_prompt = await audio_to_text(audio_file)
    elif prompt:
        user_prompt = prompt

    if not user_prompt:
        return {"text_response": "Tôi đang lắng nghe...", "audio_base64": ""}

    try:
        # Gọi Agent với tham số return_intermediate_steps=True để bắt trọn gói dữ liệu
        result = agent_with_history.invoke(
            {"input": user_prompt, "user_id": user_id},
            config={"configurable": {"session_id": f"user_{user_id}"}}
        )

        # 1. Lấy câu trả lời của AI
        ai_text = result.get("output", "")

        # 2. XỬ LÝ TRƯỜNG HỢP AI "BỊ CÂM" (Output rỗng)
        # Nếu ai_text là None, rỗng, hoặc chỉ toàn khoảng trắng
        if not ai_text or not isinstance(ai_text, str) or ai_text.strip() == "":

            # Kiểm tra xem có bước chạy tool nào không
            if "intermediate_steps" in result and result["intermediate_steps"]:
                # intermediate_steps là một list các cặp (Action, Observation)
                # Chúng ta lấy Observation (kết quả trả về) của tool cuối cùng
                last_step = result["intermediate_steps"][-1]
                # Phần tử thứ 2 là kết quả tool (chuỗi "✅ Đã tạo...")
                tool_result = last_step[1]

                # Gán trực tiếp kết quả tool làm câu trả lời
                ai_text = str(tool_result)
            else:
                # Trường hợp hiếm: Không gọi tool, cũng không nói gì
                ai_text = "Tôi đã nghe rõ, nhưng không biết phải trả lời sao. Bạn thử lại nhé?"

    except Exception as e:
        logger.error(f"Agent Error: {e}")
        ai_text = "Hệ thống đang bận, vui lòng thử lại sau."

    return {
        "user_prompt": user_prompt,
        "text_response": ai_text,
        "audio_base64": text_to_base64_audio(ai_text)
    }
