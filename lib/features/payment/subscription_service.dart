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

      if (plan == 'premium' && status == 'active' && endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        return endDate.isAfter(DateTime.now());
      }

      return false;
    } catch (e) {
      // Log error or handle it silently
      return false;
    }
  }

  Future<String?> getActivePlanName() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('subscriptions')
          .select('plan, status, end_date')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;

      final plan = response['plan'] as String?;
      final status = response['status'] as String?;
      final endDateStr = response['end_date'] as String?;

      // Check if subscription is active and not expired
      if (status == 'active' && endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        if (endDate.isAfter(DateTime.now())) {
          // Try to map plan code to display name if possible
          if (plan == 'vip_1_month') return '1 Month';
          if (plan == 'vip_6_months') return '6 Months';
          if (plan == 'vip_1_year') return '1 Year';

          // Fallback to capitalizing the plan name or returning it as is
          if (plan != null && plan.isNotEmpty) {
            return plan[0].toUpperCase() + plan.substring(1);
          }
          return 'Premium';
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<DateTime?> getSubscriptionEndDate() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('subscriptions')
          .select('status, end_date')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;

      final status = response['status'] as String?;
      final endDateStr = response['end_date'] as String?;

      if (status == 'active' && endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        if (endDate.isAfter(DateTime.now())) {
          return endDate;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
