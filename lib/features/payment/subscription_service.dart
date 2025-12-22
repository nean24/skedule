import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> isPremium() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('subscriptions')
          .select('plan, status, end_date')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return false;

      final plan = response['plan'] as String?;
      final status = response['status'] as String?;
      final endDateStr = response['end_date'] as String?;

      if (plan == 'vip' && status == 'active' && endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        return endDate.isAfter(DateTime.now());
      }

      return false;
    } catch (e) {
      // Log error or handle it silently
      return false;
    }
  }
}
