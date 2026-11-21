# do_vui_ai_thuong

A new Flutter project.

## Bạn bè

Màn Bạn bè hỗ trợ tìm người chơi theo mã/tên, gửi và xử lý lời mời, cũng như
xóa bạn. Tính năng dùng collection `public_profiles` chỉ chứa thông tin hồ sơ
công khai tối thiểu; dữ liệu người dùng riêng tư vẫn giữ quyền đọc như cũ.

Sau khi cập nhật Firestore Rules, deploy quyền truy cập bằng lệnh từ thư mục gốc:

```powershell
firebase deploy --only firestore:rules --project do-vui-ai-thuong
```

Tài khoản cũ sẽ được tạo hồ sơ công khai lần đầu mở màn Bạn bè; tài khoản mới
được tạo hồ sơ này ngay sau khi đăng ký.

## Cửa hàng

Cửa hàng luôn hiển thị danh sách xem trước, danh mục và giá vật phẩm trong lúc
API chưa kết nối. Số dư và túi đồ chỉ hiển thị sau khi tải được dữ liệu thật;
giao dịch mua không được giả lập và sẽ báo rõ khi API chưa sẵn sàng.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
