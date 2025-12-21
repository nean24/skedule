from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
from dotenv import load_dotenv

# Import router thanh toán
from payment_service import router as payment_router

# Load biến môi trường
load_dotenv()

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Khởi tạo App Minimal chỉ cho Payment
app = FastAPI(title="Skedule Payment Service")

# Cấu hình CORS (Cho phép mọi nguồn để test dễ dàng)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include router
app.include_router(payment_router)

@app.get("/")
def health_check():
    return {"status": "ok", "service": "Skedule Payment Service"}
