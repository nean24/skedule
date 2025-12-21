import hashlib
import hmac
import urllib.parse

class VNPAY:
    def __init__(self, tmn_code, secret_key, payment_url, return_url):
        self.tmn_code = tmn_code
        self.secret_key = secret_key
        self.payment_url = payment_url
        self.return_url = return_url

    def get_payment_url(self, order_id, amount, order_desc, bank_code=None, ip_addr="127.0.0.1"):
        # VNPAY requires amount to be multiplied by 100
        vnp_params = {
            "vnp_Version": "2.1.0",
            "vnp_Command": "pay",
            "vnp_TmnCode": self.tmn_code,
            "vnp_Amount": int(amount) * 100,
            "vnp_CurrCode": "VND",
            "vnp_TxnRef": order_id,
            "vnp_OrderInfo": order_desc,
            "vnp_OrderType": "other",
            "vnp_Locale": "vn",
            "vnp_ReturnUrl": self.return_url,
            "vnp_IpAddr": ip_addr,
            "vnp_CreateDate": self._get_current_time_str(),
        }

        if bank_code:
            vnp_params["vnp_BankCode"] = bank_code

        # Sort parameters by key
        input_data = sorted(vnp_params.items())
        
        # Build query string
        query_string = ""
        seq = 0
        for key, val in input_data:
            if seq == 1:
                query_string = query_string + "&" + key + "=" + urllib.parse.quote_plus(str(val))
            else:
                query_string = key + "=" + urllib.parse.quote_plus(str(val))
                seq = 1

        # Generate secure hash
        secure_hash = self._hmac_sha512(self.secret_key, query_string)
        
        # Final URL
        return f"{self.payment_url}?{query_string}&vnp_SecureHash={secure_hash}"

    def validate_response(self, vnp_params):
        # Get secure hash from params and remove it for validation
        vnp_SecureHash = vnp_params.get('vnp_SecureHash')
        if not vnp_SecureHash:
            return False
            
        params = vnp_params.copy()
        if 'vnp_SecureHash' in params:
            params.pop('vnp_SecureHash')
        if 'vnp_SecureHashType' in params:
            params.pop('vnp_SecureHashType')
            
        # Sort and build query string
        input_data = sorted(params.items())
        query_string = ""
        seq = 0
        for key, val in input_data:
            if seq == 1:
                query_string = query_string + "&" + key + "=" + urllib.parse.quote_plus(str(val))
            else:
                query_string = key + "=" + urllib.parse.quote_plus(str(val))
                seq = 1
                
        # Verify hash
        secure_hash = self._hmac_sha512(self.secret_key, query_string)
        return secure_hash == vnp_SecureHash

    def _hmac_sha512(self, key, data):
        byte_key = key.encode('utf-8')
        byte_data = data.encode('utf-8')
        return hmac.new(byte_key, byte_data, hashlib.sha512).hexdigest()

    def _get_current_time_str(self):
        from datetime import datetime
        return datetime.now().strftime('%Y%m%d%H%M%S')
