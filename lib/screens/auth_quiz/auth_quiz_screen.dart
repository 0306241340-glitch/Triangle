// Màn Đăng nhập S02 — TV1 An giữ (nhánh feat/an-auth-quiz).
// Dùng AuthViewModel (đăng nhập thật bằng Firebase Auth). Đăng nhập xong,
// AuthGate trong main.dart tự chuyển sang Trang chủ S05, không cần điều
// hướng tay. Chép đè lên file lib/screens/auth_quiz/auth_quiz_screen.dart
// đang trống trong repo rồi commit.
import 'package:flutter/material.dart';

import '../../viewmodels/auth_quiz_vm.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _vm = AuthViewModel();
  bool _isRegister = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập đủ email và mật khẩu')),
      );
      return;
    }
    final ok = _isRegister
        ? await _vm.signUp(email, password)
        : await _vm.signIn(email, password);
    if (!mounted) return;
    if (!ok && _vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_vm.error!)),
      );
    }
    // Đăng nhập đúng: AuthGate tự chuyển sang Trang chủ, không cần làm gì thêm.
  }

  Future<void> _signInWithGoogle() async {
    final ok = await _vm.signInWithGoogle();
    if (!mounted) return;
    if (!ok && _vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_vm.error!)),
      );
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập email vào ô trên trước đã')),
      );
      return;
    }
    final ok = await _vm.resetPassword(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Đã gửi mail đặt lại mật khẩu, kiểm tra hộp thư'
            : (_vm.error ?? 'Không gửi được mail, thử lại sau')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.quiz, size: 72, color: Color(0xFF2563EB)),
                  const SizedBox(height: 12),
                  const Text('Đố Vui Trắc Nghiệm',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Chơi – Học – Thi đấu cùng bạn bè'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Mật khẩu', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _vm.isLoading ? null : _submit,
                      child: _vm.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isRegister ? 'Đăng ký' : 'Đăng nhập'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _vm.isLoading ? null : _signInWithGoogle,
                      child: const Text('G Đăng nhập bằng Google'),
                    ),
                  ),
                  TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Quên mật khẩu?'),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister
                        ? 'Đã có tài khoản? Đăng nhập'
                        : 'Chưa có tài khoản? Đăng ký'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
