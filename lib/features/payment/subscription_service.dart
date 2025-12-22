import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> isPremium() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('subscriptions')
          .select('status, end_date')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return false;

      final status = response['status'] as String?;
      final endDateStr = response['end_date'] as String?;

      // Check status and date regardless of plan name
      if (status == 'active' && endDateStr != null) {
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
          .select('plan, status, start_date, end_date')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;

      final plan = response['plan'] as String?;
      final status = response['status'] as String?;
      final startDateStr = response['start_date'] as String?;
      final endDateStr = response['end_date'] as String?;

      // Check if subscription is active and not expired
      if (status == 'active' && endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        if (endDate.isAfter(DateTime.now())) {
          // Infer from dates regardless of plan name
          if (startDateStr != null) {
            final startDate = DateTime.parse(startDateStr);
            final duration = endDate.difference(startDate).inDays;

            if (duration >= 360) return '1 Year';
            if (duration >= 170) return '6 Months';
            if (duration >= 25) return '1 Month';
          }

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
