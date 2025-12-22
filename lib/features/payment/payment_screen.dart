import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;

  Future<void> _initiatePayment(int amount, String orderDesc) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw Exception('User not logged in');
      }

      // Replace with your actual backend URL
      // For Android Emulator use 10.0.2.2
      // For Real Device (Wireless Debugging), use your PC's LAN IP (e.g., 192.168.1.x)
      
      // CẤU HÌNH URL BACKEND:
      // Cách 1: Dùng IP LAN (khi dev chung mạng wifi)
      // const backendUrl = 'http://192.168.1.15:8000'; 
      
      // Cách 2: Dùng Ngrok (khi muốn test ổn định hơn hoặc khác mạng)
      // Chạy lệnh: ngrok http 8000 -> Copy link https dán vào dưới
      // const backendUrl = 'https://your-ngrok-id.ngrok-free.app'; 
      
      // Cách 3: Dùng Server Render (Đã deploy online)
      // Nếu .env có VNP_RETURN_URL=https://skedule-payment.onrender.com/payment_return
      const backendUrl = 'https://skedule-payment.onrender.com';
      
      final response = await http.post(
        Uri.parse('$backendUrl/create_payment_url'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'amount': amount,
          'order_desc': orderDesc,
          'bank_code': null, // Optional
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final paymentUrl = data['payment_url'];
        
        if (await canLaunchUrl(Uri.parse(paymentUrl))) {
          await launchUrl(
            Uri.parse(paymentUrl),
            mode: LaunchMode.externalApplication, // Open in external browser to handle deep links correctly
          );
        } else {
          throw Exception('Could not launch payment URL');
        }
      } else {
        throw Exception('Failed to create payment URL: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Plans')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPlanCard(
                    title: '1 Month',
                    price: '50,000 VND',
                    amount: 50000,
                    description: 'Skedule VIP - 1 Month',
                  ),
                  const SizedBox(height: 20),
                  _buildPlanCard(
                    title: '6 Months',
                    price: '270,000 VND',
                    amount: 270000,
                    description: 'Skedule VIP - 6 Months',
                  ),
                  const SizedBox(height: 20),
                  _buildPlanCard(
                    title: '1 Year',
                    price: '500,000 VND',
                    amount: 500000,
                    description: 'Skedule VIP - 1 Year',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required int amount,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(price, style: const TextStyle(fontSize: 18, color: Colors.green)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _initiatePayment(amount, description),
              child: const Text('Subscribe Now'),
            ),
          ],
        ),
      ),
    );
  }
}
