// lib/features/authentication/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/main.dart';
import 'signup_screen.dart';
import 'dart:developer';
import 'dart:async';

// Không cần import AuthGate ở đây nữa
// import 'package:skedule/auth_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- CÁC HÀM LOGIC ---
  String _translateAuthException(AuthException e) {
    if (e.message.contains('Invalid login credentials')) {
      return 'Email hoặc mật khẩu không chính xác.';
    }
    if (e.message.contains('Email not confirmed')) {
      return 'Tài khoản chưa được xác thực email.';
    }
    return 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _googleSignIn() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; });

    try {
      log('LoginScreen: Attempting Google sign-in...');
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.skedule://login-callback',
      );
      log('LoginScreen: Google sign-in command finished.');
      // XONG! AuthGate sẽ tự xử lý việc chuyển hướng khi nhận được sự kiện đăng nhập thành công.
    } on AuthException catch (e) {
      _showErrorSnackBar(_translateAuthException(e));
    } finally {
      // Chỉ set isLoading = false nếu không thành công, vì nếu thành công,
      // màn hình này sẽ bị thay thế, không cần build lại.
      if (mounted && supabase.auth.currentSession == null) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; });

    try {
      log('LoginScreen: Attempting password sign-in...');
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ).timeout(const Duration(seconds: 10));
      log('LoginScreen: Password sign-in command finished (SUCCESS).');
      // XONG! AuthGate sẽ tự xử lý việc chuyển hướng.
    } on TimeoutException {
      _showErrorSnackBar('Lỗi kết nối: Yêu cầu đăng nhập bị Timeout.');
    } on AuthException catch (e) {
      log('LoginScreen Auth Error: ${e.message}');
      _showErrorSnackBar(_translateAuthException(e));
    } catch (e) {
      log('LoginScreen General Error: ${e.toString()}');
      _showErrorSnackBar('Đã xảy ra lỗi không mong muốn: ${e.toString()}');
    } finally {
      if (mounted && supabase.auth.currentSession == null) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final emailForReset = _emailController.text.trim();
    if (emailForReset.isEmpty || !emailForReset.contains('@')) {
      _showErrorSnackBar('Vui lòng nhập email của bạn vào ô Email trước.');
      return;
    }

    setState(() { _isLoading = true; });
    try {
      await supabase.auth.resetPasswordForEmail(
        emailForReset,
        redirectTo: 'io.supabase.skedule://login-callback',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi link đặt lại mật khẩu. Vui lòng kiểm tra email.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch(e) {
      _showErrorSnackBar(_translateAuthException(e));
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- GIAO DIỆN (Giữ nguyên) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC3C9E4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildLoginCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/app_logo.jpg', height: 60),
          const SizedBox(height: 16),
          const Text('Welcome to Skedule', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 8),
          Text('Sign in to your account', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 32),
          _buildTextField(label: 'Email', controller: _emailController),
          const SizedBox(height: 16),
          _buildTextField(label: 'Password', controller: _passwordController, isObscure: true),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _forgotPassword,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(color: Color(0xFF4A6C8B)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6C8B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sign In', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _googleSignIn,
              icon: Image.asset('assets/google_logo.png', height: 24.0, width: 24.0),
              label: const Text('Continue with Google', style: TextStyle(color: Color(0xFF333333), fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SignUpScreen()));
                },
                child: const Text('Sign up', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A6C8B))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGETS PHỤ (Giữ nguyên) ---
  Widget _buildTextField({required String label, required TextEditingController controller, bool isObscure = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
      const SizedBox(height: 8),
      TextField(
        controller: controller, obscureText: isObscure,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true, fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    ]);
  }

  Widget _buildDivider() {
    return Row(children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text('OR CONTINUE WITH', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ),
      const Expanded(child: Divider()),
    ]);
  }
}