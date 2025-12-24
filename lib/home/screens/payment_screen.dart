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

      // --- BƯỚC 1: ĐẢM BẢO LUÔN CÓ SUBSCRIPTION_ID ---
      // Chiến thuật: Nếu chưa có thì tạo mới một dòng "giữ chỗ" (inactive)
      int subscriptionId;

      // 1.1 Tìm subscription hiện tại
      final currentSub = await Supabase.instance.client
          .from('subscriptions')
          .select('id')
          .eq('user_id', session.user.id)
          .maybeSingle();

      if (currentSub != null) {
        subscriptionId = currentSub['id'];
      } else {
        // 1.2 Nếu chưa có, tạo mới với trạng thái "chờ" (dùng 'cancelled' hoặc 'inactive' tùy enum của bạn)
        // Đặt ngày hết hạn là quá khứ để user chưa dùng được ngay
        final newSub = await Supabase.instance.client
            .from('subscriptions')
            .insert({
              'user_id': session.user.id,
              'plan': 'premium',
              'status':
                  'cancelled', // Trạng thái tạm, sẽ được Webhook đổi thành 'active' khi thanh toán xong
              'start_date': DateTime.now().toIso8601String(),
              'end_date': DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
            })
            .select('id')
            .single();

        subscriptionId = newSub['id'];
      }
      // -----------------------------------------------------

      // BƯỚC 2: Gọi Edge Function lấy link thanh toán
      final response = await Supabase.instance.client.functions.invoke(
        'payment-vnpay',
        body: {
          'amount': amount,
          'order_desc': orderDesc,
          'bank_code': null,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        final paymentUrl = data['payment_url'] ?? data['paymentUrl'];

        if (paymentUrl != null && paymentUrl is String) {
          // BƯỚC 3: Lưu vào DB với subscription_id CHẮC CHẮN CÓ
          try {
            final uri = Uri.parse(paymentUrl);
            final txnRef = uri.queryParameters['vnp_TxnRef'];

            if (txnRef != null) {
              await Supabase.instance.client.from('payments').insert({
                'user_id': session.user.id,
                'subscription_id': subscriptionId, // <--- ĐÃ CÓ ID CHÍNH XÁC
                'amount': amount,
                'status': 'pending',
                'method': 'vnpay',
                'transaction_id': txnRef,
                'created_at': DateTime.now().toIso8601String(),
              });
            }
          } catch (dbError) {
            debugPrint('Lỗi lưu payment: $dbError');
          }

          // BƯỚC 4: Mở trình duyệt
          if (await canLaunchUrl(Uri.parse(paymentUrl))) {
            await launchUrl(
              Uri.parse(paymentUrl),
              mode: LaunchMode.externalApplication,
            );
          } else {
            throw Exception('Could not launch payment URL');
          }
        } else {
          throw Exception('Payment URL is missing');
        }
      } else {
        throw Exception('Failed to create payment URL');
      }
    } catch (e) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${settings.strings.translate('error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isPremium
                  ? (_planName ?? settings.strings.translate('premium'))
                  : settings.strings.translate('upgrade_premium'),
              style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onBackground, fontWeight: FontWeight.bold),
            ),
            if (_isPremium) ...[
              const SizedBox(width: 8),
              const Icon(Icons.star, color: Colors.amber),
            ],
          ],
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    settings.strings.translate('choose_plan'),
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onBackground),
                  ),
                  const SizedBox(height: 30),
                  _buildPlanCard(
                    context,
                    title: settings.strings.translate('monthly'),
                    price: '50,000 VND',
                    duration:
                        '/${settings.strings.translate('monthly').toLowerCase()}',
                    amount: 50000,
                    description: '${settings.strings.translate('app_name')} VIP - 1 ${settings.strings.translate('monthly')}',
                    selectText: settings.strings.translate('select'),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    context,
                    title: settings.strings.translate('six_months'),
                    price: '270,000 VND',
                    duration:
                        '/6 ${settings.strings.translate('monthly').toLowerCase().replaceAll(settings.strings.translate('monthly').toLowerCase(), settings.strings.translate('six_months').toLowerCase())}',
                    amount: 270000,
                    description: '${settings.strings.translate('app_name')} VIP - 6 ${settings.strings.translate('monthly')}',
                    isPopular: true,
                    saveText: settings.strings.translate('save_10'),
                    selectText: settings.strings.translate('select'),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    context,
                    title: settings.strings.translate('yearly'),
                    price: '500,000 VND',
                    duration:
                        '/${settings.strings.translate('yearly').toLowerCase()}',
                    amount: 500000,
                    description: '${settings.strings.translate('app_name')} VIP - 1 ${settings.strings.translate('yearly')}',
                    isBestValue: true,
                    saveText: settings.strings.translate('best_value'),
                    selectText: settings.strings.translate('select'),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    settings.strings.translate('recurring_billing'),
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required String duration,
    required int amount,
    required String description,
    required String selectText,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    bool isPopular = false,
    bool isBestValue = false,
    String? saveText,
  }) {
    Color cardBg = colorScheme.surface;
    Color borderColor = colorScheme.outlineVariant;
    double borderWidth = 1.0;

    if (isPopular) {
      borderColor = colorScheme.primary;
      borderWidth = 2.0;
      cardBg = colorScheme.primary.withOpacity(0.08);
    } else if (isBestValue) {
      borderColor = Colors.amber;
      borderWidth = 2.0;
      cardBg = Colors.amber.withOpacity(0.08);
    }

    return GestureDetector(
      onTap: () => _initiatePayment(amount, description),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.05),
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
                      Text(title,
                          style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(price,
                              style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isBestValue
                                      ? Colors.amber[700]
                                      : (isPopular ? colorScheme.primary : colorScheme.onSurface))),
                          const SizedBox(width: 4),
                          Text(duration,
                              style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7))),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _initiatePayment(amount, description),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular
                        ? colorScheme.primary
                        : (isBestValue ? Colors.amber : colorScheme.surface),
                    foregroundColor: (isPopular || isBestValue)
                        ? Colors.white
                        : colorScheme.primary,
                    side: (isPopular || isBestValue)
                        ? null
                        : BorderSide(color: colorScheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    elevation: 0,
                  ),
                  child: Text(selectText,
                      style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (saveText != null)
            Positioned(
              top: -12,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isBestValue ? Colors.amber : colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  saveText,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white,
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
