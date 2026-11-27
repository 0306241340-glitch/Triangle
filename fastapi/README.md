# FastAPI + PostgreSQL — backend cho app Đố Vui

FastAPI là cổng duy nhất cho dữ liệu ứng dụng; PostgreSQL lưu hồ sơ, nội dung
quiz, điểm/xu, bạn bè, yêu thích, cửa hàng và lịch sử. Firebase Auth tiếp tục
xác thực người dùng. Firestore chỉ phát bản chiếu trạng thái PvP realtime;
FastAPI/PostgreSQL vẫn là nguồn dữ liệu và nơi quyết định đáp án, điểm số.

## Cái gì giữ nguyên, cái gì đổi

| | Express cũ | FastAPI mới (bản này) |
|---|---|---|
| Ngôn ngữ / framework | Node + Express | Python + FastAPI |
| CSDL | Firestore (NoSQL) | **PostgreSQL qua SQLAlchemy** (SQLite chỉ để phát triển/test local) |
| Đăng nhập | Firebase Auth, Bearer ID token | **Giữ nguyên** — Firebase xác thực; PostgreSQL giữ dữ liệu, Firestore chỉ phát PvP realtime |
| Dữ liệu | đọc/ghi trực tiếp từ app | qua API: `/me`, `/topics`, `/quiz-sets`, `/quiz/*`, `/friends/*`, `/favorites`, `/store/*`, `/pvp/*`, `/leaderboard`, `/admin/*` |
| Trả về | `{ok:true, data}` / `{ok:false, error:{code,message}}` | **Giữ nguyên y hệt** — `api_client.dart` đọc được luôn |
| Chấm điểm | Dễ 10đ/5xu, TB 20đ/10xu, Khó 30đ/15xu | **Giữ nguyên** — làm đúng hết 10 câu = 180đ/90xu |
| CORS | Không có (1 trong các lỗi sáng 18/11) | **Có sẵn, allow-all** |
| Tài liệu API | Không | Tự sinh tại `/docs` (Swagger UI) — thầy mở là thấy hết endpoint |

SQL dùng **PostgreSQL trên Supabase** (An đã tạo project), không dùng MS SQL
Server trong file Bài 09: file đó chạy SQL Server local trên máy, không
triển khai thuận tiện. Postgres vẫn là CSDL quan hệ và Supabase có gói Free.

## Đấu 1vs1

`/pvp/queue` ghép người chơi đang chờ theo điểm gần nhất; `/pvp/invite/{uid}`
gửi lời mời tới bạn đã kết nối. Người nhận xem lời mời tại
`/pvp/invitations`, rồi chấp nhận hoặc từ chối qua
`/pvp/rooms/{id}/accept` và `/pvp/rooms/{id}/decline`; người gửi có thể hủy
phòng đang chờ qua `/pvp/rooms/{id}/cancel`. Trong trận, app tải
trạng thái bằng `GET /pvp/rooms/{id}` và gửi một đáp án cho mỗi câu qua
`POST /pvp/rooms/{id}/answer`. Trận gồm đúng 10 câu, 15 giây mỗi câu; đáp án
đúng được 10 điểm. Máy chủ giữ đáp án đúng và chỉ trả nội dung/lựa chọn cho
người chơi. Phòng, hàng đợi, kết quả và diễn biến được lưu vào các bảng
`rooms`, `match_queue`, `match_histories` và `notifications`. Flutter nghe các
Firestore snapshots để nhận lời mời, ghép trận và cập nhật phòng ngay lập tức;
FastAPI ghi bản chiếu an toàn, còn đáp án đúng và điểm chỉ nằm trong PostgreSQL.
Tài khoản chỉ có trạng thái PvP `idle` / `in_room`, không theo dõi online/offline.
Phòng chờ hoặc trận không tiến triển quá 2 phút sẽ tự chuyển sang `cancelled`;
phòng và lịch sử vẫn được giữ trong SQL, còn trạng thái realtime chuyển về `idle`.

## Bảng SQL

`users` (khóa chính = Firebase UID) · `topics` · `quiz_sets` · `questions`
(`options` JSON, `correct_index` chỉ ở server) · `quiz_set_questions`
(liên kết câu hỏi được chọn thủ công, tự tạo khi khởi động) · `attempts` ·
`attempt_answers` · `quiz_histories` · `history_details` · `transactions` ·
`comments` · `items` · `user_items` · `favorites` · `friends` · `rooms` ·
`match_queue` · `match_histories` · `notifications` · `reports`.
Xem chi tiết trong `app/models.py`.

## Chạy local (5 phút)

Nếu đã có dữ liệu trên Supabase, tạo `fastapi/.env` từ `.env.example` và đặt
`DATABASE_URL` bằng connection string **Transaction pooler** trong Supabase
(thường dùng cổng `6543`). File `.env` được Git bỏ qua, không chia sẻ hoặc commit
file này. Nếu không cấu hình `DATABASE_URL`, backend sẽ dùng SQLite
`fastapi/quiz.db` riêng trên máy — dữ liệu trên Supabase sẽ không xuất hiện.

```bash
cd fastapi
python -m venv .venv
.venv\Scripts\activate          # Windows; Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000   # /docs
```

Chỉ chạy `python -m app.seed seed-data-3-chu-de.json` nếu muốn nạp dữ liệu mẫu
vào SQLite local; không cần chạy lệnh này khi dữ liệu đã có trên Supabase.

Chưa có `serviceAccountKey.json` thì endpoint cần token sẽ trả 401 — là đúng.
Muốn test không cần Firebase: `python test_smoke.py` (đã chạy qua, xem dưới).
Lấy file service account: Firebase Console → Project settings →
Service accounts → Generate new private key → đặt tên
`serviceAccountKey.json` trong thư mục `fastapi/` (**không commit**).

## Cấu hình khi triển khai

Repo không kèm cấu hình cho nhà cung cấp hosting. Dịch vụ FastAPI cần biến
`DATABASE_URL` trỏ tới PostgreSQL và `FIREBASE_SERVICE_ACCOUNT` chứa JSON
service account trên một dòng. Lệnh khởi chạy:

```text
uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

Khi chuyển sang host mới, cấu hình `API_BASE_URL` cho Flutter rồi kiểm tra
`/health`. Deploy Firestore Rules để client chỉ đọc projection PvP được cấp
quyền. `firebase.json` không còn khai báo Functions; Firebase Function `api`
đã triển khai trước đây cần được gỡ riêng nếu còn tồn tại.

## App Flutter

Ứng dụng gửi mọi thao tác dữ liệu qua API; cấu hình URL khi build:

```dart
flutter run --dart-define=API_BASE_URL=https://<your-api-host>
```

Không có URL API mặc định; cần truyền `API_BASE_URL` cho build hoặc run. PvP
realtime cần cấu hình `FIREBASE_SERVICE_ACCOUNT` để FastAPI ghi các bản chiếu
phòng, hàng chờ và lời mời. Mọi thao tác game vẫn đi qua API.
Trong VS Code, cấu hình Android Emulator truyền sẵn
`http://10.0.2.2:8000`; trước khi bấm Run, hãy chạy FastAPI local bằng lệnh
ở trên trong terminal riêng. Nếu dùng điện thoại thật, thay URL bằng IP LAN
của máy chạy FastAPI.

## API quản trị

Các endpoint dưới đây yêu cầu role admin và chỉ đọc dữ liệu:

- `GET /admin/stats`
- `GET /admin/quiz-sets` và `GET /admin/quiz-sets/{id}/questions`
- `GET /admin/items`, `GET /admin/users`, `GET /admin/reports`

ID vật phẩm được tạo theo loại và tên (`item_title_<slug-tên>`,
`item_frame_<slug-tên>`, `item_<slug-tên>` cho trợ giúp); có thể chỉnh sửa
trước khi lưu. Nếu trùng ID thì API tự thêm hậu tố số để đảm bảo duy nhất.
ID chủ đề/bộ đề có dạng `topic_<slug-tên>` / `set_<slug-tên>`. Số câu của chủ
đề, lượt thi và điểm trung bình của bộ đề do hệ thống tính, không nhập thủ công.

Danh sách câu hỏi lấy các câu đang hoạt động thuộc chủ đề của bộ đề; schema
hiện tại chưa lưu quan hệ câu hỏi trực tiếp với từng bộ đề.

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
Các dữ liệu cũ không tự nhập sang PostgreSQL. Chỉ giữ deployment FastAPI hiện
tại làm nguồn dữ liệu chuẩn; nếu còn dịch vụ/function cũ trên cloud, hãy gỡ
riêng sau khi chuyển traffic.
