// lib/features/authentication/screens/new_password_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/main.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  /// Xử lý việc cập nhật mật khẩu mới.
  Future<void> _updatePassword() async {
    // Chỉ tiếp tục nếu form hợp lệ
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    try {
      // Supabase tự động biết người dùng nào cần đổi mật khẩu dựa vào session từ link.
      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      if (!mounted) return;

      // 1. Gửi thông báo thành công.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.strings.translate('password_changed_success')),
          backgroundColor: Colors.green,
        ),
      );

      // 2. Đăng xuất session tạm thời để kích hoạt AuthGate điều hướng về màn hình đăng nhập.
      await supabase.auth.signOut();

    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.strings.translate('create_new_password')),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  settings.strings.translate('enter_new_password'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),

                // Trường nhập mật khẩu mới
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: settings.strings.translate('new_password'),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return settings.strings.translate('password_min_length');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Trường xác nhận mật khẩu
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: settings.strings.translate('confirm_password'),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return settings.strings.translate('passwords_mismatch');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Nút xác nhận hoặc chỉ báo tải
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  onPressed: _updatePassword,
                  child: Text(settings.strings.translate('confirm')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}