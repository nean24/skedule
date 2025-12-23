import google.generativeai as genai
import os
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")

if not api_key:
    print("❌ Lỗi: Không tìm thấy GEMINI_API_KEY trong file .env")
else:
    print(f"🔑 Đang kiểm tra với API Key: {api_key[:5]}...*****")
    try:
        genai.configure(api_key=api_key)
        print("\n--- DANH SÁCH MODEL KHẢ DỤNG ---")
        models = list(genai.list_models())
        found = False
        for m in models:
            if 'generateContent' in m.supported_generation_methods:
                print(f"- {m.name}")
                if 'flash' in m.name:
                    found = True

        if not found:
            print(
                "\n⚠️ Cảnh báo: Không thấy model nào tên là 'flash'. Hãy dùng 'gemini-pro'.")
        else:
            print(
                "\n✅ Có thấy model Flash. Hãy copy chính xác tên ở trên (bỏ chữ 'models/') vào file code.")

    except Exception as e:
        print(f"\n❌ Lỗi kết nối Google: {e}")
