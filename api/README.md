# WebAPI — App Đố Vui Trắc Nghiệm

Express chạy trên Firebase Cloud Functions. App Flutter chỉ gọi API này.

## Chạy local

```bash
cd api
npm install
# Đặt file serviceAccountKey.json vào thư mục api/ (không commit lên Git)
npm run serve
# API ở http://localhost:5001/do-vui-ai-thuong/asia-southeast1/api
```

## Deploy

```bash
firebase deploy --only functions
```

## Test nhanh

```bash
curl http://localhost:3000/health
# → {"ok":true,"data":{"status":"ok",...}}

curl http://localhost:3000/topics
# → 401 (thiếu token là đúng)
```

Thiết kế đầy đủ (30 endpoint, ví dụ request/response, checklist nghiệm thu):
`../files/thiet-ke-webapi.md`
