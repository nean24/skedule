// lib/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:developer'; // Thêm log để dễ debug

import 'package:skedule/home/screens/home_screen.dart';
import 'package:skedule/features/authentication/screens/login_screen.dart';
import 'package:skedule/features/authentication/screens/new_password_screen.dart';
import 'package:skedule/features/authentication/screens/complete_profile_screen.dart';
import 'package:skedule/main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isPasswordRecovery = false;
  bool _isLoading = true;
  Widget? _nextScreen; // Màn hình cần hiển thị

  @override
  void initState() {
    super.initState();
    _initAuthListener();
  }

  void _initAuthListener() {
    // 1. Đặt Stream Listener để theo dõi các sự kiện Auth
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (!mounted) return; // Đảm bảo widget vẫn tồn tại

      log('AuthGate Event: $event'); // Log sự kiện để debug

      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _isPasswordRecovery = true;
          _isLoading = false;
        });
        return;
      }

      // Xử lý SignedOut hoặc UserUpdated (kích hoạt kiểm tra lại)
      if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _isPasswordRecovery = false;
          _nextScreen = const LoginScreen();
          _isLoading = false;
        });
        return;
      }

      if (event == AuthChangeEvent.userUpdated) {
        // Khi user update, không cần logout, chỉ cần reload lại trạng thái nếu cần
        // Hoặc đơn giản là bỏ qua nếu không cần xử lý gì đặc biệt
        // Ở đây ta sẽ gọi lại _handleLoggedIn để đảm bảo profile mới nhất được load
        if (session != null) {
          await _handleLoggedIn(session.user.id);
        }
        return;
      }

      // Xử lý SignedIn, InitialSession hoặc TokenRefreshed
      if (session != null) {
        await _handleLoggedIn(session.user.id);
      } else {
        setState(() {
          _nextScreen = const LoginScreen();
          _isLoading = false;
        });
      }
    });

    // 2. Kiểm tra session ban đầu (ngay khi app khởi động)
    final session = supabase.auth.currentSession;
    if (session != null) {
      _handleLoggedIn(session.user.id);
    } else {
      // Đặt giá trị ban đầu nếu không có session
      _nextScreen = const LoginScreen();
      _isLoading = false;
    }
  }

  Future<void> _handleLoggedIn(String userId) async {
    // Luôn bắt đầu bằng trạng thái loading
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Truy vấn profile, chỉ cần kiểm tra cột 'name' và maybeSingle()
      // Các cột khác (gender, birth_date) có thể là NULL, không phải là điều kiện cản.
      final Map<String, dynamic>? response = await supabase
          .from('profiles')
          .select('name')
          .eq('id', userId)
          .maybeSingle(); // maybeSingle để xử lý khi profile chưa tồn tại

      final profileName = response?['name'] as String?;

      // Kiểm tra: Profile không tồn tại HOẶC tên là null HOẶC tên là chuỗi rỗng
      if (response == null || profileName == null || profileName.isEmpty) {
        log('Profile check: Incomplete. Redirecting to CompleteProfileScreen.');
        _nextScreen = const CompleteProfileScreen();
      } else {
        log('Profile check: Complete. Redirecting to HomeScreen.');
        _nextScreen = const HomeScreen();
      }
    } catch (e) {
      log('Error checking profile: $e', error: e);
      // Xử lý lỗi (ví dụ: RLS Policy) bằng cách quay về màn hình đăng nhập
      _nextScreen = const LoginScreen();
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Ưu tiên: Khôi phục mật khẩu
    if (_isPasswordRecovery) {
      return const NewPasswordScreen();
    }

    // 2. Hiển thị loading
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 3. Hiển thị màn hình tiếp theo
    // Sử dụng null-aware operator ?? để đảm bảo an toàn
    return _nextScreen ?? const LoginScreen();
  }
}