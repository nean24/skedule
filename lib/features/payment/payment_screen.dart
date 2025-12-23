import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/features/payment/subscription_service.dart';
import 'package:skedule/features/settings/settings_provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  bool _isPremium = false;
  String? _planName;
  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final isPremium = await _subscriptionService.isPremium();
    final planName = await _subscriptionService.getActivePlanName();
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
        _planName = planName;
      });
    }
  }

  Future<void> _initiatePayment(int amount, String orderDesc) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw Exception('User not logged in');
      }

      // Gọi Edge Function 'payment-vnpay'
      final response = await Supabase.instance.client.functions.invoke(
        'payment-vnpay',
        body: {
          'amount': amount,
          'order_desc': orderDesc,
          'bank_code': null, // Optional
        },
      );

      if (response.status == 200) {
        final data = response.data;
        final paymentUrl = data['payment_url'];
        
        // Thêm kiểm tra null và kiểu String
        if (paymentUrl != null && paymentUrl is String) {
          if (await canLaunchUrl(Uri.parse(paymentUrl))) {
            await launchUrl(
              Uri.parse(paymentUrl),
              mode: LaunchMode.externalApplication, // Open in external browser to handle deep links correctly
            );
          } else {
            throw Exception('Could not launch payment URL');
          }
        } else {
          throw Exception('Payment URL is missing or invalid');
        }
      } else {
        throw Exception('Failed to create payment URL: ${response.data}');
      }
    } catch (e) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${settings.strings.translate('error')}: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              _isPremium ? (_planName ?? settings.strings.translate('premium')) : settings.strings.translate('upgrade_premium'),
              style: const TextStyle(color: Colors.black),
            ),
            if (_isPremium) ...[
              const SizedBox(width: 8),
              const Icon(Icons.star, color: Colors.amber),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    settings.strings.translate('unlock_full_potential'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A6C8B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    settings.strings.translate('get_access_exclusive'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  _buildFeatureItem(Icons.check_circle, settings.strings.translate('full_ai_integration')),
                  _buildFeatureItem(Icons.check_circle, settings.strings.translate('no_ads')),
                  _buildFeatureItem(Icons.check_circle, settings.strings.translate('advanced_scheduling')),
                  _buildFeatureItem(Icons.check_circle, settings.strings.translate('unlimited_tasks')),
                  const SizedBox(height: 40),
                  Text(
                    settings.strings.translate('choose_plan'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildPlanCard(
                    title: settings.strings.translate('monthly'),
                    price: '50,000 VND',
                    duration: '/${settings.strings.translate('monthly').toLowerCase()}',
                    amount: 50000,
                    description: 'Skedule VIP - 1 Month',
                    color: Colors.blue.shade50,
                    textColor: Colors.blue.shade900,
                    selectText: settings.strings.translate('select'),
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    title: settings.strings.translate('six_months'),
                    price: '270,000 VND',
                    duration: '/6 ${settings.strings.translate('monthly').toLowerCase().replaceAll('monthly', 'months')}', // Approximate
                    amount: 270000,
                    description: 'Skedule VIP - 6 Months',
                    isPopular: true,
                    saveText: settings.strings.translate('save_10'),
                    selectText: settings.strings.translate('select'),
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    title: settings.strings.translate('yearly'),
                    price: '500,000 VND',
                    duration: '/${settings.strings.translate('yearly').toLowerCase()}',
                    amount: 500000,
                    description: 'Skedule VIP - 1 Year',
                    color: Colors.amber.shade50,
                    textColor: Colors.amber.shade900,
                    borderColor: Colors.amber,
                    saveText: settings.strings.translate('best_value'),
                    selectText: settings.strings.translate('select'),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    settings.strings.translate('recurring_billing'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A6C8B), size: 24),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String duration,
    required int amount,
    required String description,
    required String selectText,
    bool isPopular = false,
    String? saveText,
    Color? color,
    Color? textColor,
    Color? borderColor,
  }) {
    final cardColor = color ?? Colors.white;
    final textCol = textColor ?? Colors.black;
    final borderCol = borderColor ?? (isPopular ? const Color(0xFF4A6C8B) : Colors.grey.shade300);
    final borderWidth = isPopular || borderColor != null ? 2.0 : 1.0;

    return GestureDetector(
      onTap: () => _initiatePayment(amount, description),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textCol)),
                          const SizedBox(width: 4),
                          Text(duration, style: TextStyle(fontSize: 14, color: textCol.withOpacity(0.7))),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _initiatePayment(amount, description),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular ? const Color(0xFF4A6C8B) : Colors.white,
                    foregroundColor: isPopular ? Colors.white : const Color(0xFF4A6C8B),
                    side: isPopular ? null : const BorderSide(color: Color(0xFF4A6C8B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(selectText),
                ),
              ],
            ),
          ),
          if (saveText != null)
            Positioned(
              top: -12,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  saveText,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
