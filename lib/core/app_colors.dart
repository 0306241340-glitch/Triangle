import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Chặn khởi tạo đối tượng trực tiếp

  // Màu chủ đạo (Primary) - Xanh dương đậm & Tím chàm
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF4F46E5);

  // Màu nhấn (Accent) - Vàng hổ phách (xu thưởng, huy hiệu Top)
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentDark = Color(0xFF92400E);

  // Màu trạng thái (Đáp án đúng / sai)
  static const Color success = Color(0xFF10B981); // Xanh lá
  static const Color error = Color(0xFFEF4444);   // Đỏ

  // Màu nền & chữ trung tính
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Colors.black54;

  // Phân loại màu theo mức độ khó (dành cho Quiz)
  static Color levelColor(String level) {
    switch (level) {
      case 'easy':
        return success;
      case 'medium':
        return accent;
      case 'hard':
        return error;
      default:
        return primaryLight;
    }
  }
}