# WebAPI — App Đố Vui Trắc Nghiệm

Express chạy trên Firebase Cloud Functions hoặc Render. App Flutter chỉ gọi API này.

## Cài đặt

```bash
cd api
npm install
```

Chạy server Express trực tiếp để phát triển:

```bash
npm start
# API ở http://localhost:3000
```

Để chạy Firebase Emulator hoặc deploy Functions, chạy lệnh từ thư mục gốc repo.
Khi chạy local, đặt `serviceAccountKey.json` trong `api/` nếu cần credentials;
không commit file này.

```bash
firebase emulators:start --only functions --project do-vui-ai-thuong
firebase deploy --only functions:api --project do-vui-ai-thuong
```

Sau khi deploy, function `api` sẽ phục vụ các route ở
`https://asia-southeast1-do-vui-ai-thuong.cloudfunctions.net/api`.

## Kiểm tra

```bash
curl https://asia-southeast1-do-vui-ai-thuong.cloudfunctions.net/api/health
# → {"ok":true,"data":{"status":"ok",...}}

curl https://asia-southeast1-do-vui-ai-thuong.cloudfunctions.net/api/topics
# → 401 (thiếu token là đúng)
```

## Deploy lên Render

1. Tạo một Blueprint từ repository này trên Render; Render sẽ đọc `render.yaml`
   và tạo web service `triangle-api` với thư mục gốc là `api/`.
2. Tạo Firebase service account có quyền truy cập Firebase Authentication và
   Firestore. Lưu toàn bộ JSON key vào biến môi trường Render
   `FIREBASE_SERVICE_ACCOUNT_JSON` (không đưa key vào Git hoặc file cấu hình).
3. Sau khi deploy xong, kiểm tra `https://<service>.onrender.com/health`.
   App mặc định dùng URL Render hiện tại; nếu dùng service khác, cấu hình URL
   gốc (không thêm `/api`) khi build:

   ```bash
   flutter run --dart-define=API_BASE_URL=https://<service>.onrender.com
   ```

   Thay `<service>` bằng hostname Render được cấp. Không thêm dấu `/` cuối URL.
   Khi build Android, iOS hoặc web, truyền cùng `--dart-define` vào lệnh build.
4. Render Free có thể tạm dừng service khi không dùng; request đầu có thể cần
   chờ service khởi động lại.

Lệnh chạy trên Render là `npm start`; ứng dụng lắng nghe port trong biến
`PORT` do Render cấp. Firebase Admin đọc credentials từ
`FIREBASE_SERVICE_ACCOUNT_JSON`.

## Cửa hàng

- `GET /store/items` trả danh sách vật phẩm đang bán, số xu và túi đồ của người dùng.
- `POST /store/purchase` với `{ "itemId": "item_frame_gold" }` mua vật phẩm.
- `POST /store/equip` với `{ "itemId": "item_frame_gold", "equipped": true }`
  trang bị hoặc tháo khung avatar/danh hiệu đã sở hữu.
- Mỗi giao dịch kiểm tra số dư và quyền sở hữu rồi trừ xu, cập nhật `user_items`,
  đồng thời ghi `transactions` trong cùng một Firestore transaction. Gói trợ giúp
  có thể mua nhiều lần; khung avatar và danh hiệu chỉ mua một lần.

Thiết kế đầy đủ (30 endpoint, ví dụ request/response, checklist nghiệm thu):
`../files/thiet-ke-webapi.md`
