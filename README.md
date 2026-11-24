# do_vui_ai_thuong

A new Flutter project.

## Lưu trữ và đăng nhập

Firebase Auth chỉ xác thực tài khoản. Hồ sơ, câu hỏi, kết quả, bạn bè, yêu
thích, vật phẩm và số dư đều được đọc/ghi qua FastAPI vào PostgreSQL. Cấu hình
`API_BASE_URL` cho Flutter và `DATABASE_URL` PostgreSQL cho FastAPI; xem
[fastapi/README.md](./fastapi/README.md) để chạy và deploy.

## Cửa hàng

Cửa hàng và túi đồ chỉ hiển thị dữ liệu từ PostgreSQL. Khi API không sẵn sàng,
ứng dụng báo lỗi thay vì hiển thị dữ liệu mẫu hoặc giả lập giao dịch.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
