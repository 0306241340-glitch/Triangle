  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:flutter/material.dart';

  import 'core/app_theme.dart';
  import 'firebase_options.dart';
  import 'screens/auth_quiz/login_screen.dart';
  import 'screens/auth_quiz/splash_screen.dart';
  import 'screens/home_profile/home_screen.dart';

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
        title: 'Đố Vui Ai Thưởng',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      );
    }
  }
  class AuthGate extends StatelessWidget {
    const AuthGate({super.key});

    @override
    Widget build(BuildContext context) {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      );
    }
  }