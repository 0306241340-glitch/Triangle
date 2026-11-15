import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_theme.dart'; // <-- Import theme
import 'screens/auth_quiz/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đố Vui Ai Thương',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // <-- Áp dụng màu chủ đạo cho toàn bộ app
      home: const SplashScreen(),
    );
  }
}