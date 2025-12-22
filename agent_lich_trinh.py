from dotenv import load_dotenv
import os
import io
import base64
import logging
from datetime import date, datetime, timedelta  # Đã thêm timedelta để tránh crash
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy import text
from gtts import gTTS
import speech_recognition as sr
from pydub import AudioSegment

# --- PHẦN IMPORT QUAN TRỌNG ---
# Với LangChain 0.3.27, nếu import lỗi, hãy thử cách dự phòng bên dưới
try:
    from langchain.agents import AgentExecutor, create_tool_calling_agent
except ImportError:
    # Fallback cho một số cấu trúc thư mục đặc thù
    from langchain.agents.agent import AgentExecutor
    from langchain.agents import create_tool_calling_agent

from langchain.tools import tool
from langchain_core.chat_history import BaseChatMessageHistory
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.runnables.history import RunnableWithMessageHistory
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.chat_message_histories import ChatMessageHistory

from utils.thoi_gian_tu_nhien import parse_natural_time
from app_dependencies import get_current_user_id, engine, supabase
# from payment_service import router as payment_router

# --- 1. CẤU HÌNH & KẾT NỐI ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    logger.warning("⚠️ Chưa tìm thấy GEMINI_API_KEY trong .env")

# Cấu hình AI Brain
llm_brain = ChatGoogleGenerativeAI(
    model="gemini-pro-latest",
    google_api_key=GEMINI_API_KEY,
    temperature=0.7
)

# --- 2. XỬ LÝ ÂM THANH ---


def clean_text_for_speech(text: str) -> str:
    return text.replace('*', '').replace('_', '').replace('-', '.')


def text_to_base64_audio(text: str) -> str:
    try:
        tts = gTTS(clean_text_for_speech(text), lang='vi')
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

# --- 3. CÁC CÔNG CỤ (TOOLS) ---


@tool
def lay_ten_nguoi_dung(user_id: str) -> str:
    """Lấy thông tin chi tiết người dùng (Tên, Email, Số task chưa làm) để chào hỏi."""
    try:
        with engine.connect() as connection:
            # [cite_start]1. Lấy thông tin cơ bản (Tên, Email) từ bảng profiles [cite: 322, 323]
            profile_query = text(
                "SELECT name, email FROM public.profiles WHERE id = :user_id;")
            profile = connection.execute(
                profile_query, {"user_id": user_id}).fetchone()

            if not profile or not profile.name:
                return "Chào bạn, tôi chưa có thông tin của bạn trong hệ thống. Tôi có thể giúp gì?"

            # [cite_start]2. Đếm sơ bộ số task chưa hoàn thành (Basic Info) [cite: 333, 334]
            task_query = text(
                "SELECT COUNT(*) FROM tasks WHERE user_id = :user_id AND is_completed = FALSE;")
            pending_count = connection.execute(
                task_query, {"user_id": user_id}).scalar()

            # 3. Trả về đúng format bạn yêu cầu
            return (
                f"Bạn là {profile.name} (Email: {profile.email}). "
                f"Theo dữ liệu, bạn đang có {pending_count} công việc chưa hoàn thành. "
                "Tôi có thể giúp gì cho bạn hôm nay?"
            )

    except Exception as e:
        return f"Lỗi lấy thông tin: {e}. Chào bạn, tôi có thể giúp gì?"


@tool
def tao_su_kien_toan_dien(tieu_de: str, loai_su_kien: str, user_id: str, mo_ta: Optional[str] = None,
                          bat_dau: Optional[str] = None, ket_thuc: Optional[str] = None,
                          uu_tien: str = 'medium') -> str:
    """Tạo sự kiện, task và lịch trình."""
    try:
        with engine.connect() as conn:
            with conn.begin():
                start_dt, end_dt = None, None
                now = datetime.now()

                if bat_dau:
                    start_dt, temp_end = parse_natural_time(bat_dau, now)
                    if temp_end and not end_dt:
                        end_dt = temp_end
                if ket_thuc:
                    _, end_dt = parse_natural_time(ket_thuc, start_dt or now)

                # Tạo Event
                event_id = conn.execute(text("""
                    INSERT INTO events (user_id, title, description, type, start_time, end_time)
                    VALUES (:uid, :title, :desc, :type, :start, :end) RETURNING id
                """), {
                    "uid": user_id, "title": tieu_de, "desc": mo_ta,
                    "type": loai_su_kien, "start": start_dt, "end": end_dt
                }).scalar()

                # Tạo Task
                if loai_su_kien in ['task', 'deadline']:
                    conn.execute(text("""
                        INSERT INTO tasks (user_id, event_id, title, description, deadline, priority, status)
                        VALUES (:uid, :eid, :title, :desc, :dl, :pri, 'todo')
                    """), {
                        "uid": user_id, "eid": event_id, "title": tieu_de,
                        "desc": mo_ta, "dl": end_dt or start_dt, "pri": uu_tien
                    })

                # Tạo Schedule
                if start_dt and loai_su_kien != 'deadline':
                    # Fix lỗi timedelta ở đây
                    final_end = end_dt if end_dt else (
                        start_dt + timedelta(hours=1))
                    conn.execute(text("""
                        INSERT INTO schedules (user_id, event_id, start_time, end_time)
                        VALUES (:uid, :eid, :start, :end)
                    """), {
                        "uid": user_id, "eid": event_id, "start": start_dt, "end": final_end
                    })

                return f"✅ Đã tạo {loai_su_kien}: '{tieu_de}' lúc {start_dt}."
    except Exception as e:
        logger.error(f"Lỗi tạo sự kiện: {e}")
        return f"❌ Có lỗi xảy ra: {str(e)}"


@tool
def tao_ghi_chu_thong_minh(noi_dung: str, user_id: str, context_title: Optional[str] = None) -> str:
    """Tạo ghi chú."""
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
        return f"Lỗi ghi chú: {e}"


@tool
def xoa_su_kien_toan_tap(tieu_de: str, user_id: str) -> str:
    """Xóa sự kiện."""
    try:
        with engine.connect() as conn:
            with conn.begin():
                res = conn.execute(text("DELETE FROM events WHERE user_id = :uid AND title ILIKE :t"),
                                   {"uid": user_id, "t": f"%{tieu_de}%"})
            return f"🗑️ Đã xóa '{tieu_de}'." if res.rowcount > 0 else "⚠️ Không tìm thấy sự kiện."
    except Exception as e:
        return f"Lỗi xóa: {e}"


# --- 4. AGENT ---
tools = [lay_ten_nguoi_dung, tao_su_kien_toan_dien,
         tao_ghi_chu_thong_minh, xoa_su_kien_toan_tap]

system_prompt = f"""
Bạn là Skedule AI Agent. Hôm nay là {date.today().strftime('%d/%m/%Y')}

QUY TẮC CỐT LÕI:
1. KHI CHÀO HỎI (đầu cuộc hội thoại):
   - BẮT BUỘC gọi tool `lay_ten_nguoi_dung`.
   - Dùng CHÍNH XÁC nội dung tool trả về để đáp lại User (vì tool đã format sẵn câu "Bạn là...").
   - KHÔNG tự chế thêm lời chào khác.

2. CÁC HÀNH ĐỘNG KHÁC:
   - Tự động dùng 'medium' cho độ ưu tiên nếu thiếu.
   - Tự suy luận loại event (deadline, class, task...) từ ngữ cảnh.
   - Trả lời ngắn gọn, đi thẳng vào vấn đề.
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
    if session_id not in store:
        store[session_id] = ChatMessageHistory()
    return store[session_id]


agent_with_history = RunnableWithMessageHistory(
    agent_executor,
    get_history,
    input_messages_key="input",
    history_messages_key="chat_history"
)

# --- 5. API ---
app = FastAPI(title="Skedule AI Agent v1.5")
# app.include_router(payment_router)


@app.post("/chat")
async def chat(prompt: Optional[str] = Form(None), audio_file: Optional[UploadFile] = File(None), user_id: str = Depends(get_current_user_id)):
    user_prompt = ""
    if audio_file:
        user_prompt = await audio_to_text(audio_file)
    elif prompt:
        user_prompt = prompt

    if not user_prompt:
        return {"text_response": "Bạn cần giúp gì?", "audio_base64": ""}

    try:
        # Gọi Agent
        result = agent_with_history.invoke(
            {"input": user_prompt, "user_id": user_id},
            config={"configurable": {"session_id": f"user_{user_id}"}}
        )
        ai_text = result.get("output", "Xin lỗi, tôi không hiểu.")
    except Exception as e:
        logger.error(f"AI Error: {e}")
        ai_text = "Hệ thống đang gặp lỗi xử lý."

    return {
        "user_prompt": user_prompt,
        "text_response": ai_text,
        "audio_base64": text_to_base64_audio(ai_text)
    }
