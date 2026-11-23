# FastAPI + PostgreSQL — backend cho app Đố Vui

FastAPI là cổng duy nhất cho dữ liệu ứng dụng; PostgreSQL lưu hồ sơ, nội dung
quiz, điểm/xu, bạn bè, yêu thích, cửa hàng và lịch sử. Firebase chỉ dùng cho
Firebase Auth; FastAPI xác thực Firebase ID token trước khi truy cập PostgreSQL.

## Cái gì giữ nguyên, cái gì đổi

| | Express cũ (Render) | FastAPI mới (bản này) |
|---|---|---|
| Ngôn ngữ / framework | Node + Express | Python + FastAPI |
| CSDL | Firestore (NoSQL) | **PostgreSQL qua SQLAlchemy** (SQLite chỉ để phát triển/test local) |
| Đăng nhập | Firebase Auth, Bearer ID token | **Giữ nguyên** — Firebase chỉ xác thực; dữ liệu ứng dụng không lưu ở Firebase |
| Dữ liệu | đọc/ghi trực tiếp từ app | qua API: `/me`, `/topics`, `/quiz-sets`, `/quiz/*`, `/friends/*`, `/favorites`, `/store/*`, `/pvp/*`, `/leaderboard`, `/admin/*` |
| Trả về | `{ok:true, data}` / `{ok:false, error:{code,message}}` | **Giữ nguyên y hệt** — `api_client.dart` đọc được luôn |
| Chấm điểm | Dễ 10đ/5xu, TB 20đ/10xu, Khó 30đ/15xu | **Giữ nguyên** — làm đúng hết 10 câu = 180đ/90xu |
| CORS | Không có (1 trong các lỗi sáng 18/11) | **Có sẵn, allow-all** |
| Tài liệu API | Không | Tự sinh tại `/docs` (Swagger UI) — thầy mở là thấy hết endpoint |

SQL dùng **PostgreSQL trên Supabase** (An đã tạo project), không dùng MS SQL
Server trong file Bài 09: file đó chạy SQL Server local trên máy, không
deploy lên Render/demo được. Postgres vẫn là CSDL quan hệ, đúng yêu cầu
của thầy, và Supabase có gói Free.

## Đấu 1vs1

`/pvp/queue` ghép người chơi đang chờ theo điểm gần nhất; `/pvp/invite/{uid}`
gửi lời mời tới bạn đã kết nối. Người nhận xem lời mời tại
`/pvp/invitations`, rồi chấp nhận hoặc từ chối qua
`/pvp/rooms/{id}/accept` và `/pvp/rooms/{id}/decline`. Trong trận, app tải
trạng thái bằng `GET /pvp/rooms/{id}` và gửi một đáp án cho mỗi câu qua
`POST /pvp/rooms/{id}/answer`. Trận gồm đúng 10 câu, 15 giây mỗi câu; đáp án
đúng được 10 điểm. Máy chủ giữ đáp án đúng và chỉ trả nội dung/lựa chọn cho
người chơi. Phòng, hàng đợi, kết quả và diễn biến được lưu vào các bảng
`rooms`, `match_queue`, `match_histories` và `notifications`.

## Bảng SQL

`users` (khóa chính = Firebase UID) · `topics` · `quiz_sets` · `questions`
(`options` JSON, `correct_index` chỉ ở server) · `attempts` ·
`attempt_answers` · `quiz_histories` · `history_details` · `transactions` ·
`comments` · `items` · `user_items` · `favorites` · `friends` · `rooms` ·
`match_queue` · `match_histories` · `notifications` · `reports`.
Xem chi tiết trong `app/models.py`.

## Chạy local (5 phút)

```bash
cd fastapi
python -m venv .venv
.venv\Scripts\activate          # Windows; Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
python -m app.seed ../files/seed-data-3-chu-de.json   # 3 chủ đề, 3 bộ đề, 30 câu, 5 vật phẩm
uvicorn app.main:app --reload   # http://127.0.0.1:8000, tài liệu: /docs
```

Chưa có `serviceAccountKey.json` thì endpoint cần token sẽ trả 401 — là đúng.
Muốn test không cần Firebase: `python test_smoke.py` (đã chạy qua, xem dưới).
Lấy file service account: Firebase Console → Project settings →
Service accounts → Generate new private key → đặt tên
`serviceAccountKey.json` trong thư mục `fastapi/` (**không commit**).

## Deploy lên Render (miễn phí)

1. Đẩy thư mục `fastapi/` lên GitHub (nhánh `dev`) sao cho `render.yaml`
   nằm ở gốc repo (hoặc đặt Root Directory = `fastapi` khi tạo Blueprint
   từ repo Triangle) — Render chỉ đọc `render.yaml` ở gốc.
2. Render → New → Blueprint → chọn repo → dùng sẵn file `render.yaml`:
   nó chỉ tạo 1 Web Service (`quiz-app-api-fastapi`), **không tạo
   Postgres trên Render nữa** — CSDL là Supabase An đã tạo, nên Render
   không có mục Database / External Database URL cho API này.
3. Web Service → Environment → thêm 2 biến:
   - `DATABASE_URL` = chuỗi **Transaction pooler** của Supabase
     (cổng 6543, `?pgbouncer=true`) — chính chuỗi An dùng để seed
     trên máy local. Nếu mật khẩu có ký tự `@` thì ghi `%40` thay cho
     `@` trong chuỗi này, giống lúc seed.
   - `FIREBASE_SERVICE_ACCOUNT` = toàn bộ nội dung file service
     account JSON trên 1 dòng (giống cách Express cũ dùng biến này).
4. Không cần seed lại trên Render: Supabase **chính là** CSDL production,
   seed An chạy trên máy local đã nạp dữ liệu vào đó rồi (3 chủ đề,
   3 bộ đề, 30 câu, 5 vật phẩm, 2 user). Chạy seed 2 lần cũng không
   nhân đôi dữ liệu, nhưng không cần làm lại.
   (Seed đã sửa email 2 user về đúng tài khoản thật: An
   `0306241340@caothang.edu.vn`, Ngọc `0306241382@caothang.edu.vn` —
   file cũ ghi `test@quiz.app` / `admin@quiz.app` là sai, 2 tài khoản đó
   không tồn tại.)
5. Kiểm tra: `curl https://<ten-service>.onrender.com/health`
   → `{"ok":true,...}`; `curl .../topics` → 401 là đúng (thiếu token).

## App Flutter

Ứng dụng gửi mọi thao tác dữ liệu qua API; cấu hình URL khi build:

```dart
flutter run --dart-define=API_BASE_URL=https://<api-service>.onrender.com
```

Đặt `DATABASE_URL` trỏ tới PostgreSQL trên dịch vụ FastAPI. Không cần deploy
Firestore Rules cho luồng dữ liệu mới.

## Đã kiểm thử (18/11, máy này)

`python test_smoke.py` — **ALL SMOKE TESTS PASSED**:
seed 3 topics / 3 sets / 30 câu / 5 items / 2 users; `/health` 200;
`/topics` đúng 3; start trả 10 câu, không lộ `correctIndex`;
50/50 ẩn đúng 2 sai, không ẩn đúng, trừ 30 xu, bấm lại cùng câu → 409;
trả lời đúng hết → 180đ/90xu, nộp lại → 409 (không cộng 2 lần);
user 0→180đ, xu 100→70→160; bộ đề attemptCount 1, avgScore 180;
comment, leaderboard (hạng 1, 180đ), history đều đúng.
Chạy `uvicorn` thật: `/health` 200, `/topics` không token → 401 đúng,
`/docs` 200. Seed chạy 2 lần không nhân đôi dữ liệu.
Sửa 18/11 trưa: seed từng lỗi `ForeignKeyViolation` trên Supabase vì
`models.py` lúc đầu chỉ viết `ForeignKey` mà không khai `relationship()` —
SQLAlchemy khi đó chèn theo tên class A-Z nên chèn `questions` trước cả
`topics`. Đã thêm `relationship()` cho mọi khóa ngoại; kiểm chứng bằng
`python test_fk.py` (bật kiểm tra khóa ngoại như Postgres): seed + start +
submit 180đ + comment + admin đều qua.

## Lưu ý — dữ liệu cũ không tự chuyển

Điểm/xu/lịch sử An đã chơi trên Firestore (test 17–18/11) **không tự
sang SQL**. Seed mới bắt đầu lại từ 0đ/100 xu cho mọi tài khoản.
Chấp nhận được vì đó mới là dữ liệu test; nếu thầy muốn giữ, cần
export Firestore → import SQL (việc riêng, báo mình làm sau).
API Express cũ trên Render vẫn chạy cho tới khi An đổi base URL —
đổi URL là lúc chính thức chuyển, trước đó cứ test FastAPI song song.
