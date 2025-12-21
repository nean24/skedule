import 'dart:io'; // Thêm import này
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:skedule/auth_gate.dart';
import 'package:app_links/app_links.dart'; // Import app_links
import 'dart:async';

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinkListener() async {
    _appLinks = AppLinks();

    // Check initial link if app was launched by a deep link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      // Handle error
      debugPrint('Error getting initial link: $e');
    }

    // Listen for new deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received deep link: $uri');
    // Check if it's the payment return URL
    if (uri.scheme == 'io.supabase.skedule' && uri.host == 'payment-result') {
      // Extract parameters
      final vnpResponseCode = uri.queryParameters['vnp_ResponseCode'];
      final message = vnpResponseCode == '00' ? 'Payment Successful!' : 'Payment Failed';
      
      // Show dialog or navigate
      // Since we don't have a global navigator key easily accessible here without context,
      // we might need to use a GlobalKey<NavigatorState> or handle this in a widget down the tree.
      // For simplicity, let's assume we use a GlobalKey.
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Payment Result')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    vnpResponseCode == '00' ? Icons.check_circle : Icons.error,
                    color: vnpResponseCode == '00' ? Colors.green : Colors.red,
                    size: 100,
                  ),
                  const SizedBox(height: 20),
                  Text(message, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add navigator key
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
