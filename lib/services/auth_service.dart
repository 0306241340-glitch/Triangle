// AuthService — đăng nhập thật bằng Firebase Auth (TV1 An giữ).
// Cần chạy trước (xem HUONG-DAN-TUAN2-TV1-PHAN2.md):
//   flutter pub add firebase_core firebase_auth google_sign_in:^6.2.1
//   flutterfire configure --project=do-vui-ai-thuong
// Sau khi đăng nhập thành công, ID token được gắn vào ApiClient để mọi
// request gọi WebAPI đều kèm Authorization: Bearer <token>.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/api_client.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, ApiClient? api})
    : _auth = auth ?? FirebaseAuth.instance,
      _api = api ?? ApiClient();

  final FirebaseAuth _auth;
  final ApiClient _api;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _attachToken();
    return cred;
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _attachToken();
    return cred;
  }

  /// Đăng nhập Google. Tài khoản Google KHÔNG có mật khẩu nên màn Đổi mật khẩu
  /// phải ẩn với user này (xem UC03).

  Future<UserCredential?> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize();

    final googleUser = await GoogleSignIn.instance.authenticate();

    final googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);

    await _attachToken();

    return cred;
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
    _api.setToken(null);
  }

  Future<void> _attachToken() async {
    final token = await _auth.currentUser?.getIdToken();
    _api.setToken(token);
  }
}
