import os
import logging
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlalchemy import text

from utils.vnpay import VNPAY
from app_dependencies import get_current_user_id, engine

# Setup Logger
logger = logging.getLogger(__name__)

# VNPAY Config
VNP_TMN_CODE = os.getenv("VNP_TMN_CODE")
VNP_HASH_SECRET = os.getenv("VNP_HASH_SECRET")
VNP_URL = os.getenv("VNP_URL")
VNP_RETURN_URL = os.getenv("VNP_RETURN_URL")

router = APIRouter()

class PaymentRequest(BaseModel):
    amount: int
    order_desc: str
    bank_code: str | None = None

@router.post("/create_payment_url")
async def create_payment_url(
    request: PaymentRequest,
    user_id: str = Depends(get_current_user_id)
):
    if not all([VNP_TMN_CODE, VNP_HASH_SECRET, VNP_URL, VNP_RETURN_URL]):
        raise HTTPException(status_code=500, detail="VNPAY configuration missing")

    vnp = VNPAY(VNP_TMN_CODE, VNP_HASH_SECRET, VNP_URL, VNP_RETURN_URL)
    
    # Generate unique order ID
    import time
    order_id = f"{user_id}_{int(time.time())}"
    
    payment_url = vnp.get_payment_url(
        order_id=order_id,
        amount=request.amount,
        order_desc=request.order_desc,
        bank_code=request.bank_code,
        ip_addr="127.0.0.1" # In production, get real IP
    )
    
    return {"payment_url": payment_url}

@router.get("/payment_return")
async def payment_return(request: Request):
    if not all([VNP_TMN_CODE, VNP_HASH_SECRET, VNP_URL, VNP_RETURN_URL]):
        raise HTTPException(status_code=500, detail="VNPAY configuration missing")

    vnp = VNPAY(VNP_TMN_CODE, VNP_HASH_SECRET, VNP_URL, VNP_RETURN_URL)
    vnp_params = dict(request.query_params)
    
    logger.info(f"Payment Return Params: {vnp_params}")

    if vnp.validate_response(vnp_params):
        response_code = vnp_params.get('vnp_ResponseCode')
        # Redirect URL scheme for the app
        app_redirect_url = f"io.supabase.skedule://payment-result?vnp_ResponseCode={response_code}"
        
        if response_code == '00':
            # Payment successful
            try:
                # Extract info
                txn_ref = vnp_params.get('vnp_TxnRef')
                amount = int(vnp_params.get('vnp_Amount', 0)) / 100
                transaction_no = vnp_params.get('vnp_TransactionNo')
                
                # Parse user_id from txn_ref (format: user_id_timestamp)
                if txn_ref and '_' in txn_ref:
                    user_id = txn_ref.rsplit('_', 1)[0]
                else:
                    logger.error(f"Invalid vnp_TxnRef format: {txn_ref}")
                    return RedirectResponse(url=app_redirect_url + "&error=invalid_txn_ref")

                logger.info(f"Processing payment for User ID: {user_id}, Amount: {amount}")

                # Database operations
                with engine.connect() as connection:
                    # Sử dụng transaction tường minh để kiểm soát lỗi tốt hơn
                    trans = connection.begin()
                    try:
                        # 0. KIỂM TRA VÀ TẠO PROFILE NẾU CHƯA CÓ
                        # Bảng subscriptions tham chiếu profiles(id), nếu thiếu profile sẽ lỗi FK.
                        check_profile_query = text("SELECT id FROM profiles WHERE id = :user_id")
                        profile_exists = connection.execute(check_profile_query, {"user_id": user_id}).fetchone()
                        
                        if not profile_exists:
                            logger.warning(f"Profile missing for user {user_id}. Creating default profile.")
                            # Lấy email từ auth.users nếu có thể (ở đây ta không truy cập được auth.users trực tiếp dễ dàng qua SQL thuần nếu không có quyền)
                            # Tạo profile dummy để pass FK constraint
                            create_profile_query = text("""
                                INSERT INTO profiles (id, name, email)
                                VALUES (:user_id, :name, :email)
                            """)
                            # Lưu ý: Email và Name ở đây là placeholder, lý tưởng nhất là lấy từ metadata hoặc auth
                            connection.execute(create_profile_query, {
                                "user_id": user_id,
                                "name": "User", 
                                "email": f"{user_id}@placeholder.com" 
                            })

                        # 1. Check current subscription
                        check_sub_query = text("""
                            SELECT plan, start_date, end_date, status 
                            FROM subscriptions 
                            WHERE user_id = :user_id
                        """)
                        current_sub = connection.execute(check_sub_query, {"user_id": user_id}).fetchone()

                        # Determine duration based on amount
                        days_to_add = 30
                        if amount >= 500000:
                            days_to_add = 365
                        elif amount >= 270000:
                            days_to_add = 180
                        
                        now = datetime.now()
                        
                        # Tính toán ngày tháng
                        final_start_date = now
                        final_end_date = now + timedelta(days=days_to_add)

                        if current_sub and current_sub.plan == 'vip' and current_sub.status == 'active' and current_sub.end_date and current_sub.end_date > now:
                            # Extend existing VIP subscription
                            logger.info("Extending existing VIP subscription")
                            final_start_date = current_sub.start_date
                            final_end_date = current_sub.end_date + timedelta(days=days_to_add)
                        else:
                            logger.info("Creating new or renewing expired subscription")

                        # Upsert Subscription
                        upsert_sub_query = text("""
                            INSERT INTO subscriptions (user_id, plan, start_date, end_date, status)
                            VALUES (:user_id, 'vip', :start_date, :end_date, 'active')
                            ON CONFLICT (user_id) 
                            DO UPDATE SET 
                                plan = 'vip',
                                status = 'active',
                                start_date = :start_date,
                                end_date = :end_date
                            RETURNING id;
                        """)
                        
                        result = connection.execute(upsert_sub_query, {
                            "user_id": user_id,
                            "start_date": final_start_date,
                            "end_date": final_end_date
                        })
                        subscription_id = result.scalar_one()
                        
                        # 2. Create Payment Record
                        insert_payment_query = text("""
                            INSERT INTO payments (user_id, subscription_id, method, amount, status, transaction_id)
                            VALUES (:user_id, :subscription_id, 'vnpay', :amount, 'completed', :transaction_id);
                        """)
                        
                        connection.execute(insert_payment_query, {
                            "user_id": user_id,
                            "subscription_id": subscription_id,
                            "amount": amount,
                            "transaction_id": transaction_no
                        })
                        
                        trans.commit()
                        logger.info(f"Payment processed successfully. Subscription ID: {subscription_id}")
                        
                    except Exception as db_err:
                        trans.rollback()
                        logger.error(f"Database transaction failed: {db_err}")
                        raise db_err
                        
            except Exception as e:
                logger.error(f"Error processing payment: {e}")
                app_redirect_url += f"&error={e}"
        
        return RedirectResponse(url=app_redirect_url)
    else:
        logger.error("Invalid VNPAY signature")
        return {"status": "error", "message": "Invalid signature", "data": vnp_params}
