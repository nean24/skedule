# **🗂️ TÀI LIỆU THIẾT KẾ CƠ SỞ DỮ LIỆU (DATABASE DESIGN DOCUMENT)**

**Sản phẩm:** Skedule  
 **Hệ quản trị:** PostgreSQL (Supabase)  
 **Phiên bản:** 1.5 – **Ngày:** 28/10/2025

---

## **I. MỤC TIÊU CẬP NHẬT**

* Chuyển sang **Event-Based Architecture**: thêm bảng `events` làm thực thể trung tâm.

* Tăng toàn vẹn dữ liệu (data integrity): bổ sung `ON DELETE CASCADE`, ENUM hóa, trigger auto-update `updated_at`.

* Mở rộng **XOR logic** cho `notes` để hỗ trợ: note có thể gắn vào **event** hoặc **task** hoặc **schedule** (chỉ 1 trong 3).

* Chuẩn bị cho đồng bộ AI & đa thiết bị: thêm `ai_suggestions`, `activity_log`.

* Hỗ trợ `checklist_items` cho tasks, cải thiện index để tối ưu truy vấn theo `user_id`, `status`, `time`.

---

## **II. TỔNG QUAN CSDL**

* Triển khai: **PostgreSQL** (trên Supabase).

* Chuẩn hóa đến **3NF**.

* Mọi quan hệ FK chính đều có **ON DELETE CASCADE** (trừ nơi có ghi chú đặc biệt).

* Trigger `set_updated_at()` để auto cập nhật `updated_at`.

* Tất cả bảng chính được gắn với `user_id` (trừ `auth.users`), đảm bảo tương thích sync theo người dùng.

---

## **III. CÁC THAY ĐỔI CHÍNH (so với v1.4)**

* **Thêm bảng `events`** (là supertype/parent cho tất cả hoạt động).

* **Tạo ENUM `event_type`** (`task`, `note`, `schedule`, `class`, `workshift`, `deadline`, `custom`).

* **Thêm cột `event_id`** (FK → events.id) vào `tasks`, `schedules`, `notes`.

* **Mở rộng XOR logic cho notes**: chỉ cho phép **1 trong 3** (`event_id`, `task_id`, `schedule_id`) khác NULL.

* **Giữ hoặc thêm ENUMs** cho `task_status`, `task_priority`, `schedule_recurring`, `reminder_status`, `subscription_plan`, `subscription_status`, `activity_type`.

* **ON DELETE CASCADE** cho FK user→profiles, tasks→events etc.

* **Trigger set\_updated\_at()** áp dụng cho tất cả bảng có `updated_at`.

* Thêm `ai_suggestions` và `activity_log` để phục vụ AI và audit.

---

## **IV. QUAN HỆ CHÍNH (ERD \- cập nhật)**

`auth.users ||--|| profiles : has one`  
`profiles ||--|| subscriptions : has one`  
`profiles ||--o{ events : owns`  
`events ||--o{ tasks : contains (1–1 ext)`  
`events ||--o{ schedules : contains (1–1 ext)`  
`events ||--o{ notes : contains (N–1)`  
`tasks ||--o{ checklist_items : contains`  
`tasks }o--o{ tags : tagged by (via task_tags)`  
`tasks ||--o{ reminders : has`  
`profiles ||--o{ ai_suggestions : receives`  
`profiles ||--o{ activity_log : records`

Ghi chú: `events` là trung tâm: `tasks`, `schedules`, `notes`, `reminders` có thể tham chiếu `event_id`.

---

## **V. TỪ ĐIỂN DỮ LIỆU (CHI TIẾT BẢNG & TRƯỜNG)**

### **profiles**

* `id` uuid PRIMARY KEY (FK → auth.users.id ON DELETE CASCADE)

* `name` varchar

* `avatar_url` text

* `settings_json` jsonb

* `birth_date` date

* `gender` text

* `email` text UNIQUE

* `updated_at` timestamptz (auto-update via trigger)

---

### **events ← MỚI**

* `id` bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY

* `user_id` uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE

* `title` varchar NOT NULL

* `description` text

* `type` event\_type NOT NULL DEFAULT 'task' \-- ENUM (task, note, schedule, class, workshift, deadline, custom)

* `start_time` timestamptz NULL

* `end_time` timestamptz NULL

* `recurring` schedule\_recurring DEFAULT 'none' \-- reused ENUM

* `location` text NULL

* `created_at` timestamptz DEFAULT now()

* `updated_at` timestamptz DEFAULT now()

* CONSTRAINT `events_time_check` CHECK (end\_time IS NULL OR end\_time \> start\_time)

Mục đích: gom nhóm mọi hành động/khối thời gian; UI & AI thao tác trên đây.

---

### **tasks**

* `id` bigint PRIMARY KEY

* `user_id` uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE

* `event_id` bigint NULL REFERENCES public.events(id) ON DELETE CASCADE

* `title` varchar NOT NULL

* `description` text

* `deadline` timestamptz NULL \-- task-level deadline (có thể khác event.end\_time)

* `priority` task\_priority DEFAULT 'medium'

* `status` task\_status DEFAULT 'todo'

* `is_completed` boolean NOT NULL DEFAULT false

* `created_at`, `updated_at` timestamptz (trigger)

Ghi chú: task có thể tồn tại độc lập (event\_id NULL) hoặc là phần của event.

---

### **checklist\_items**

* `id` bigint PRIMARY KEY

* `task_id` bigint NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE

* `content` text NOT NULL

* `is_checked` boolean DEFAULT false

* `created_at`, `updated_at` timestamptz

---

### **notes**

* `id` bigint PRIMARY KEY

* `user_id` uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE

* `event_id` bigint NULL REFERENCES public.events(id) ON DELETE CASCADE

* `task_id` bigint NULL REFERENCES public.tasks(id) ON DELETE CASCADE

* `schedule_id` bigint NULL REFERENCES public.schedules(id) ON DELETE CASCADE

* `content` text NOT NULL \-- supports Markdown

* `created_at`, `updated_at` timestamptz

**CHECK (XOR) constraint:** chỉ cho phép **một trong ba** `event_id`, `task_id`, `schedule_id` khác NULL.  
 Ví dụ constraint (Postgres):

`CHECK (`  
  `(CASE WHEN event_id IS NOT NULL THEN 1 ELSE 0 END) +`  
  `(CASE WHEN task_id IS NOT NULL THEN 1 ELSE 0 END) +`  
  `(CASE WHEN schedule_id IS NOT NULL THEN 1 ELSE 0 END)`  
  `= 1`  
`)`

Ghi chú: logic này buộc note luôn có một context duy nhất.

---

### **schedules**

* `id` bigint PRIMARY KEY

* `user_id` uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE

* `event_id` bigint NULL REFERENCES public.events(id) ON DELETE CASCADE

* `task_id` bigint NULL REFERENCES public.tasks(id) ON DELETE CASCADE \-- optional link

* `start_time` timestamptz NOT NULL

* `end_time` timestamptz NOT NULL

* `recurring` schedule\_recurring DEFAULT 'none'

* `created_at`, `updated_at` timestamptz

* CONSTRAINT CHECK (end\_time \> start\_time)

---

### **reminders**

* `id` bigint PRIMARY KEY

* `user_id` uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE

* `event_id` bigint NULL REFERENCES public.events(id) ON DELETE CASCADE

* `task_id` bigint NULL REFERENCES public.tasks(id) ON DELETE CASCADE

* `remind_time` timestamptz NOT NULL

* `type` reminder\_type DEFAULT 'default'

* `status` reminder\_status DEFAULT 'pending'

* `created_at` timestamptz DEFAULT now()

Ghi chú: reminder có thể liên kết vào event hoặc task; chúng không được cùng lúc (nên enforce logic tương tự nếu cần).

---

### **tags**

* `id` bigint PRIMARY KEY

* `user_id` uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE

* `name` varchar NOT NULL

* `color` varchar NULL

* UNIQUE (`user_id`, `name`)

---

### **task\_tags**

* `task_id` bigint REFERENCES public.tasks(id) ON DELETE CASCADE

* `tag_id` bigint REFERENCES public.tags(id) ON DELETE CASCADE

* PRIMARY KEY (`task_id`, `tag_id`)

---

### **subscriptions**

* `id` bigint PRIMARY KEY

* `user_id` uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE

* `plan` subscription\_plan DEFAULT 'free'

* `start_date` timestamptz NOT NULL

* `end_date` timestamptz NOT NULL

* `status` subscription\_status DEFAULT 'active'

* `created_at` timestamptz DEFAULT now()

---

### **payments**

* `id` bigint PRIMARY KEY

* `user_id` uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE

* `subscription_id` bigint NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE

* `method` varchar DEFAULT 'momo'

* `amount` numeric NOT NULL

* `status` payment_status DEFAULT 'pending' -- user-defined enum in existing schema

* `transaction_id` varchar NOT NULL UNIQUE

* `created_at` timestamptz DEFAULT now()

---

### **ai\_suggestions**

* `id` bigint PRIMARY KEY

* `user_id` uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE

* `task_context` jsonb NULL

* `suggestion_text` text NOT NULL

* `confidence` numeric(3,2) NULL

* `created_at` timestamptz DEFAULT now()

---

### **activity\_log**

* `id` bigint PRIMARY KEY

* `user_id` uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE

* `activity_type` activity\_type NOT NULL

* `metadata` jsonb NULL

* `created_at` timestamptz DEFAULT now()

---

## **VI. ENUM TYPES (SQL snippets)**

`CREATE TYPE task_status AS ENUM ('todo', 'in_progress', 'done');`  
`CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high');`  
`CREATE TYPE schedule_recurring AS ENUM ('none', 'daily', 'weekly', 'monthly');`  
`CREATE TYPE reminder_status AS ENUM ('pending', 'sent', 'expired');`  
`CREATE TYPE subscription_plan AS ENUM ('free', 'vip');`  
`CREATE TYPE subscription_status AS ENUM ('active', 'expired', 'cancelled');`  
`CREATE TYPE activity_type AS ENUM ('task_created', 'task_completed', 'note_added', 'login', 'payment');`

`-- NEW: event_type`  
`CREATE TYPE event_type AS ENUM ('task','note','schedule','class','workshift','deadline','custom');`

---

## **VII. INDEXING STRATEGY**

Tối ưu truy vấn theo user & thời gian:

`CREATE INDEX idx_events_user_id_start_time ON public.events(user_id, start_time DESC);`  
`CREATE INDEX idx_tasks_user_id_status ON public.tasks(user_id, status);`  
`CREATE INDEX idx_schedules_user_id_start_time ON public.schedules(user_id, start_time DESC);`  
`CREATE INDEX idx_reminders_remind_time_status ON public.reminders(remind_time, status);`  
`CREATE INDEX idx_tags_user_id ON public.tags(user_id);`  
`CREATE INDEX idx_ai_suggestions_user_id ON public.ai_suggestions(user_id);`  
`CREATE INDEX idx_activity_log_user_id_time ON public.activity_log(user_id, created_at DESC);`

---

## **VIII. ER DIAGRAM (TỔNG QUAN \- cập nhật)**

`auth.users ||--|| profiles : has one`  
`profiles ||--|| subscriptions : has one`  
`profiles ||--o{ events : owns`  
`events ||--o{ tasks : contains`  
`events ||--o{ schedules : contains`  
`events ||--o{ notes : contains`  
`tasks ||--o{ checklist_items : contains`  
`tasks }o--o{ tags : tagged by (via task_tags)`  
`tasks ||--o{ reminders : has`  
`profiles ||--o{ ai_suggestions : receives`  
`profiles ||--o{ activity_log : records`

Gợi ý: cập nhật sơ đồ hiển thị rõ `events` là node trung tâm.

---

## **IX. TRIGGER & FUNCTION (auto-updated timestamps)**

Hàm cập nhật `updated_at`:

`CREATE OR REPLACE FUNCTION set_updated_at()`  
`RETURNS TRIGGER AS $$`  
`BEGIN`  
  `NEW.updated_at = NOW();`  
  `RETURN NEW;`  
`END;`  
`$$ LANGUAGE plpgsql;`

Gắn trigger cho các bảng có `updated_at`:

`CREATE TRIGGER trigger_set_updated_at_profiles`  
`BEFORE UPDATE ON public.profiles`  
`FOR EACH ROW`  
`EXECUTE FUNCTION set_updated_at();`

`CREATE TRIGGER trigger_set_updated_at_events`  
`BEFORE UPDATE ON public.events`  
`FOR EACH ROW`  
`EXECUTE FUNCTION set_updated_at();`

`CREATE TRIGGER trigger_set_updated_at_tasks`  
`BEFORE UPDATE ON public.tasks`  
`FOR EACH ROW`  
`EXECUTE FUNCTION set_updated_at();`

`CREATE TRIGGER trigger_set_updated_at_schedules`  
`BEFORE UPDATE ON public.schedules`  
`FOR EACH ROW`  
`EXECUTE FUNCTION set_updated_at();`

`CREATE TRIGGER trigger_set_updated_at_notes`  
`BEFORE UPDATE ON public.notes`  
`FOR EACH ROW`  
`EXECUTE FUNCTION set_updated_at();`

`CREATE TRIGGER trigger_set_updated_at_checklist_items`  
`BEFORE UPDATE ON public.checklist_items`  
`FOR EACH ROW`  
`EXECUTE FUNCTION set_updated_at();`

---

## **X. RÀNG BUỘC ĐẶC BIỆT (XOR logic cho notes)**

Đặt ràng buộc CHECK để đảm bảo `notes` chỉ liên kết đúng 1 ngữ cảnh:

`ALTER TABLE public.notes`  
`ADD CONSTRAINT notes_one_parent_check CHECK (`  
  `(CASE WHEN event_id IS NOT NULL THEN 1 ELSE 0 END) +`  
  `(CASE WHEN task_id IS NOT NULL THEN 1 ELSE 0 END) +`  
  `(CASE WHEN schedule_id IS NOT NULL THEN 1 ELSE 0 END)`  
  `= 1`  
`);`

Ghi chú: nếu bạn muốn cho phép `note` độc lập (không gắn gì), thay điều kiện `= 1` thành `<= 1`.

---

## **XI. MIGRATION NOTES (Gợi ý script & thứ tự triển khai)**

**Lưu ý:** order của migration quan trọng (tạo type trước khi dùng, tạo parent trước child, áp trigger sau khi cột `updated_at` tồn tại).

1. Tạo các ENUM mới (`event_type`, nếu chưa có).

2. Tạo bảng `events`.

3. Thêm cột `event_id` vào `tasks`, `schedules`, `notes` (nullable) và tạo FK `ON DELETE CASCADE`.

4. Áp CHECK XOR cho `notes`.

5. Tạo trigger `set_updated_at()` và gắn vào các bảng.

6. Tạo/điều chỉnh index.

7. Kiểm tra data migration: nếu có dữ liệu `tasks`/`schedules`/`notes` cũ, map sang `events` theo logic nghiệp vụ (ví dụ: tạo event mặc định rồi gán `event_id` cho entities hiện có) hoặc giữ `event_id NULL` nếu không muốn group.

Ví dụ snippet (tóm tắt):

`-- 1. create type`  
`CREATE TYPE event_type AS ENUM ('task','note','schedule','class','workshift','deadline','custom');`

`-- 2. create events table`  
`CREATE TABLE public.events (...);`

`-- 3. alter tasks`  
`ALTER TABLE public.tasks ADD COLUMN event_id BIGINT REFERENCES public.events(id) ON DELETE CASCADE;`

`-- 4. alter schedules`  
`ALTER TABLE public.schedules ADD COLUMN event_id BIGINT REFERENCES public.events(id) ON DELETE CASCADE;`

`-- 5. alter notes`  
`ALTER TABLE public.notes ADD COLUMN event_id BIGINT REFERENCES public.events(id) ON DELETE CASCADE;`

`-- 6. add XOR constraint for notes (see above)`

---

## **XII. GHI CHÚ & KIẾN NGHỊ**

* **Event-based** giúp UI và AI cùng xử lý context (AI dễ phân tích group of activities).

* Giữ `event_id` nullable cho backward compatibility — cho phép lộ trình migrate dần.

* Nếu bạn muốn enforce mọi task/schedule phải thuộc event, set `event_id NOT NULL` và migrate dữ liệu trước.

* Lưu ý khi sử dụng ENUM: thêm value mới cần `ALTER TYPE ... ADD VALUE` (thực hiện cẩn trọng trong production). Nếu cần dynamic categories do users tạo, cân nhắc thêm bảng `event_types` thay vì ENUM.

