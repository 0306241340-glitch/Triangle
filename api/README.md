# WebAPI — App Đố Vui Trắc Nghiệm

Express chạy trên Firebase Cloud Functions. App Flutter chỉ gọi API này.

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
Đặt `serviceAccountKey.json` trong `api/` nếu cần credentials khi chạy local;
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

## Cửa hàng

- `GET /store/items` trả danh sách vật phẩm đang bán, số xu và túi đồ của người dùng.
- `POST /store/purchase` với `{ "itemId": "item_frame_gold" }` mua vật phẩm.
- Mỗi giao dịch kiểm tra số dư và quyền sở hữu rồi trừ xu, cập nhật `user_items`,
  đồng thời ghi `transactions` trong cùng một Firestore transaction. Gói trợ giúp
  có thể mua nhiều lần; khung avatar và danh hiệu chỉ mua một lần.

Thiết kế đầy đủ (30 endpoint, ví dụ request/response, checklist nghiệm thu):
`../files/thiet-ke-webapi.md`
