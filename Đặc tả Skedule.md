# **🧩 TÀI LIỆU ĐẶC TẢ YÊU CẦU PHẦN MỀM (SRS)**

**Sản phẩm:** Skedule (Ứng dụng di động)  
 **Phiên bản:** 1.5  **Ngày:** 28/10/2025

---

## **1.0 GIỚI THIỆU**

### **1.1 Mục đích**

Tài liệu này mô tả chi tiết yêu cầu chức năng và phi chức năng của ứng dụng **Skedule**, nhằm thống nhất giữa nhóm **phát triển, kiểm thử, thiết kế, AI và vận hành**.

### **1.2 Tổng quan sản phẩm**

**Skedule** là ứng dụng quản lý thời gian và công việc cá nhân **dựa trên mô hình sự kiện (Event-Based Architecture)**.  
 Người dùng có thể tạo, quản lý và tự động sắp xếp **mọi loại hoạt động trong cuộc sống** — từ việc học, làm việc, ghi chú, đến ca làm và hạn chót — chỉ trong **một hệ thống duy nhất gọi là Event**.

Ứng dụng giúp người dùng:

* Tổ chức thời gian và công việc khoa học hơn

* Tăng năng suất và giảm stress

* Hạn chế quên deadline hoặc chồng chéo lịch

* Nhận gợi ý sắp xếp thông minh từ **AI Agent**

  ---

  ## **2.0 KIẾN TRÚC HỆ THỐNG VÀ CÔNG NGHỆ**

  ### **2.1 Công nghệ sử dụng**


| Thành phần | Công nghệ | Mô tả |
| ----- | ----- | ----- |
| **Frontend (Mobile App)** | Flutter (Dart) | Ứng dụng đa nền tảng (iOS \+ Android) |
| **Backend API** | Supabase | RESTful API tự động sinh từ PostgreSQL |
| **Cloud Database** | PostgreSQL | CSDL chính, quan hệ & JSONB |
| **Local Database** | SQLite / Hive | Lưu offline-first, đồng bộ sau khi có mạng |
| **Authentication** | Supabase Auth | Email/Mật khẩu \+ OAuth (Google) |
| **Thanh toán** | VNPAY Payment SDK | Kênh thanh toán chính để  nâng cấp và gia hạn VIP |
| **Thông báo** | Firebase Cloud Messaging | Push notification theo event/reminder |
| **AI Agent** | Python (FastAPI \+ LangChain) | Phân tích thói quen, gợi ý tự động |
| **Design System** | Figma | Quản lý UI Kit và Prototype chính thức |

### **2.2 Mô hình dữ liệu chính (Event-Based)**

#### **Thực thể trung tâm: `events`**

Tất cả hoạt động trong ứng dụng được gom vào **bảng `events`**, có kiểu (`type`) xác định loại sự kiện.

**event.type (ENUM):**

* `task` – Công việc

* `note` – Ghi chú

* `schedule` – Lịch

* `class` – Lớp học

* `workshift` – Ca làm

* `deadline` – Hạn chót

#### **Liên kết và bảng con:**

| Bảng | Khóa chính / Khóa ngoại | Mối quan hệ | Các trường chính | Mô tả |
| ----- | ----- | ----- | ----- | ----- |
| **tasks** | `id`, `event_id` (FK → events) | 1–1 với `events` | `priority`, `status`, `is_completed` | Mở rộng logic Task: trạng thái, độ ưu tiên, checklist |
| **notes** | `id`, `event_id` (FK → events) | N–1 với `events` | `content`, `created_at`, `updated_at` | Nhiều ghi chú gắn với một event |
| **schedules** | `id`, `event_id` (FK → events) | 1–1 với `events` | `start_time`, `end_time`, `recurring` | Thời gian, lặp lại (recurring rule) |
| **reminders** | `id`, `event_id` (FK → events) | N–1 với `events` | `remind_time`, `type`, `status` | Nhắc nhở dựa trên thời gian event |
| **checklist\_items** | `id`, `task_id` (FK → tasks) | N–1 qua `task_id` | `item_text`, `is_done` | Mục con trong Task |
| **tags** | `id`, `user_id` (FK → profiles) | 1–N với `profiles` | `name` | Tag do người dùng tạo |
| **task\_tags** | `task_id` (FK → tasks), `tag_id` (FK → tags) | N–N | – | Phân loại linh hoạt cho các event/task |
| **profiles** | `id` | 1–N với tất cả các bảng | `name`, `avatar_url`, `email` | Người dùng (user\_id liên kết tất cả bảng) |
| **payments** | `id`, `user_id`, `subscription_id` | N–1 với `subscriptions` | `method`, `amount`, `status`, `transaction_id` | Thanh toán MoMo, lưu lịch sử giao dịch |
| **subscriptions** | `id`, `user_id` | 1–1 với `profiles` | `plan`, `start_date`, `end_date`, `status` | Gói VIP người dùng |
| **ai\_suggestions** | `id`, `user_id` | 1–N với `profiles` | `suggestion`, `context_json`, `created_at` | Dữ liệu AI, gợi ý từ trợ lý |
| **activity\_log** | `id`, `user_id` | 1–N với `profiles` | `action`, `target_id`, `target_type`, `created_at` | Nhật ký hoạt động hệ thống |

## **3.0 YÊU CẦU CHỨC NĂNG**

### **3.1 Quản lý tài khoản & xác thực**

* Đăng ký Email/Mật khẩu hoặc đăng nhập Google

* Cập nhật hồ sơ cá nhân (tên, avatar, ngày sinh)

* Phân quyền người dùng: **Normal / VIP**

---

### **3.2 Quản lý sự kiện (Event Management)**

* CRUD trên tất cả các loại event (Task, Note, Schedule, Class, Workshift, Deadline)

* Tất cả tạo qua **một modal duy nhất (Add Event Modal)**

* Thuộc tính chung: tiêu đề, mô tả, thời gian, loại (type), recurring

* Giao diện timeline hiển thị sự kiện theo ngày / tuần / tháng

---

### **3.3 Công việc (Task)**

* Event type \= `task`

* Thuộc tính mở rộng: priority, status, checklist

* Có thể liên kết tag, reminder, note

* Hỗ trợ kéo-thả sắp xếp lại thứ tự trong timeline

---

### **3.4 Lịch & Ca làm (Schedule / Workshift / Class)**

* Event type \= `schedule`, `workshift`, `class`

* Hiển thị dạng block trên timeline/calendar

* VIP có thể kéo thả (drag & drop) để đổi thời gian

* Hỗ trợ recurring (daily/weekly/monthly)

---

### **3.5 Deadline**

* Event type \= `deadline`

* Có thể liên kết với Task

* AI tự động nhắc hoặc chia nhỏ công việc trước hạn

---

### **3.6 Ghi chú (Note)**

* Event type \= `note` hoặc note gắn vào event khác

* CRUD nội dung dạng text / markdown

* Có thể tìm kiếm và lọc theo từ khóa

---

### **3.7 Nhắc nhở (Reminders)**

* Tạo nhắc nhở cho event bất kỳ

* Gửi push notification khi gần tới thời điểm

* VIP: AI tự điều chỉnh thời gian nhắc phù hợp thói quen

---

### **3.8 Trợ lý AI (AI Agent)**

* Giao diện chat trực quan

* Hiểu lệnh tự nhiên:

  * “Tạo task học tiếng Anh lúc 7h tối”

  * “Gợi ý lịch học tuần này”

* AI gợi ý:

  * Sắp xếp lại lịch

  * Cảnh báo xung đột thời gian

  * Tối ưu hoá work-life balance

---

### **3.9 Thanh toán & VIP**

* Thanh toán qua MoMo SDK

* Nâng cấp từ Normal → VIP

* Gia hạn tự động hoặc thủ công

* Theo dõi lịch sử giao dịch trong Profile

---

## **4.0 VAI TRÒ NGƯỜI DÙNG**

| Chức năng | Normal | VIP |
| ----- | ----- | ----- |
| Quản lý tài khoản | ✔️ | ✔️ |
| Sự kiện / Công việc | ✔️ (Cơ bản) | ✔️ (Không giới hạn) |
| Timeline | ✔️ (Xem) | ✔️ (Kéo thả \+ AI) |
| Notes | ✔️ | ✔️ (Markdown \+ Sync) |
| Notification | ✔️ | ✔️ (AI thông minh) |
| Chat AI | Giới hạn | Không giới hạn |
| Đồng bộ đa thiết bị | ❌ | ✔️ |
| Thanh toán | ✔️ (Nâng cấp) | ✔️ (Gia hạn) |

## **5.0 YÊU CẦU PHI CHỨC NĂNG**

* **Offline-first:** Dữ liệu lưu cục bộ, tự đồng bộ khi có mạng

* **Bảo mật:** Hash mật khẩu, JWT token, RLS (Row Level Security)

* **Hiệu năng:** Load dưới 2s với \<1000 event/user

* **Mở rộng:** Có thể thêm loại event mới mà không đổi cấu trúc chính

* **Tính ổn định:** 99.9% uptime với Supabase backend

---

## **6.0 GIAO DIỆN NGƯỜI DÙNG (UI/UX)**

| Vai trò | Mã màu |
| ----- | ----- |
| Nền chính | \#B5BAD0 |
| Accent / Ngày chọn | \#416788 |
| Chữ sáng | \#E0E0E2 |
| Nền thẻ / Card | \#FFFFFF |

**Màu theo loại event:**

* workshift → Orange

* class → Blue

* deadline → Red

* task → Green

* schedule → Purple

* note → Gray

### **Figma Reference**

**Figma:** `Skedule v1.5 – Event-Based UI Kit`  
 **GitHub:** `nean24/skedule`  
 **Supabase Dashboard:** Auth \+ Database Schema

---

## **7.0 TỔNG KẾT**

Phiên bản **Skedule v1.5** đánh dấu bước chuyển quan trọng sang **kiến trúc event-based**, giúp thống nhất mọi loại hoạt động (task, schedule, note, v.v.) thành một cấu trúc duy nhất.  
 Cách tổ chức này giúp AI dễ phân tích, hệ thống dễ mở rộng, và trải nghiệm người dùng liền mạch hơn.

