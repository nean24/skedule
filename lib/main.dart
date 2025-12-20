import 'dart:io'; // Thêm import này
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:skedule/auth_gate.dart';

// === BƯỚC 1: TẠO MỘT CLASS ĐỂ GHI ĐÈ CÁC QUY TẮC HTTP ===
// Class này sẽ bảo Flutter bỏ qua các lỗi chứng chỉ SSL.
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // === BƯỚC 2: KÍCH HOẠT QUY TẮC GHI ĐÈ TRƯỚC KHI CHẠY APP ===
  // Dòng này phải được đặt trước khi có bất kỳ request mạng nào.
  HttpOverrides.global = MyHttpOverrides();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

// KHÔNG CẦN HÀM _listenForAuthEvents ở đây nữa, logic đã chuyển vào AuthGate

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Skedule',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // KHÔNG CẦN navigatorKey nữa
      home: const AuthGate(),
    );
  }
}

final supabase = Supabase.instance.client;
