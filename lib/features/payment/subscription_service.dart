import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Kiểm tra xem user có gói Premium hợp lệ không
  Future<bool> isPremium() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Lấy thông tin subscription mới nhất
      final response = await _supabase
          .from('subscriptions')
          .select('status, end_date')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return false;

      final status = response['status'] as String?;
      final endDateStr = response['end_date'] as String?;

      // Logic: Phải có status là 'active' VÀ ngày hết hạn phải sau thời điểm hiện tại
      if (status == 'active' && endDateStr != null) {
        final endDate = DateTime.parse(endDateStr).toLocal();
        return endDate.isAfter(DateTime.now());
      }

      return false;
    } catch (e) {
      // Có thể log lỗi nếu cần thiết
      return false;
    }
  }

  /// Hàm kiểm tra quyền sử dụng AI (Hard Gate)
  /// Hiện tại logic là: Chỉ Premium mới được dùng.
  /// Tách riêng hàm này để sau này nếu bạn đổi ý (ví dụ cho dùng thử 3 lần lưu local)
  /// thì chỉ cần sửa ở đây mà không ảnh hưởng logic isPremium gốc.
  Future<bool> canUseAi() async {
    return await isPremium();
  }

  /// Lấy tên gói để hiển thị (VD: "1 Year", "Premium")
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

      if (status == 'active' && endDateStr != null) {
        final endDate = DateTime.parse(endDateStr).toLocal();

        if (endDate.isAfter(DateTime.now())) {
          // Cố gắng đoán tên gói dựa trên khoảng thời gian
          if (startDateStr != null) {
            final startDate = DateTime.parse(startDateStr).toLocal();
            final duration = endDate.difference(startDate).inDays;

            if (duration >= 360) return '1 Year';
            if (duration >= 170) return '6 Months';
            if (duration >= 25) return '1 Month';
          }

          // Nếu không đoán được, format lại tên plan từ DB
          if (plan != null && plan.isNotEmpty) {
            // Viết hoa chữ cái đầu (premium -> Premium)
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

  /// Lấy ngày hết hạn để hiển thị
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
        final endDate = DateTime.parse(endDateStr).toLocal();
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
