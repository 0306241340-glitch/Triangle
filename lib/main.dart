// main.dart — thay file main.dart mặc định của repo bằng file này.
// Cần chạy trước: flutterfire configure --project=do-vui-ai-thuong
// (tạo ra file lib/firebase_options.dart). Nếu chưa chạy lệnh đó thì app
// sẽ báo thiếu file firebase_options.dart — chạy lệnh rồi build lại.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_quiz/auth_quiz_screen.dart';
import 'screens/home_profile/home_profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đố Vui Trắc Nghiệm',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2563EB),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Chưa đăng nhập -> màn Đăng nhập S02; đã đăng nhập -> Trang chủ S05.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.hasData ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
