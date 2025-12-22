from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from payment_service import router as payment_router
import logging

# Cấu hình logging để xem lỗi trên Render dễ hơn
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Cấu hình CORS (Cho phép mọi nguồn truy cập - quan trọng cho Mobile App)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Kết nối router thanh toán
app.include_router(payment_router)

@app.get("/")
def read_root():
    logger.info("Health check endpoint called")
    return {"status": "online", "message": "Skedule Payment Server is running"}