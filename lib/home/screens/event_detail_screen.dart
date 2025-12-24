import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/features/settings/settings_provider.dart';

// --- BẢNG MÀU ĐỒNG BỘ (Copy từ CalendarScreen để đảm bảo consistency) ---
// (Nên xóa class AppColors này nếu đã dùng app_theme.dart toàn app)

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isTask;

  const EventDetailScreen({
    super.key,
    required this.data,
    required this.isTask,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _supabase = Supabase.instance.client;
  late bool _isCompleted;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.data['is_completed'] ?? false;
  }

  Future<void> _toggleComplete() async {
    if (!widget.isTask) return;
    setState(() => _isLoading = true);
    try {
      final bool newStatus = !_isCompleted;
      final String statusText = newStatus ? 'done' : 'todo';
      await _supabase.from('tasks').update({
        'is_completed': newStatus,
        'status': statusText,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.data['id']);

      setState(() {
        _isCompleted = newStatus;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi update: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa mục này không?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      final table = widget.isTask ? 'tasks' : 'events';
      await _supabase.from(table).delete().eq('id', widget.data['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = colorScheme.background;
    final cardColor = colorScheme.surface;
    final textColor = colorScheme.onSurface;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    // Màu nhấn dựa trên loại
    final accentColor = widget.isTask ? colorScheme.primary : colorScheme.secondary;

    // Format thời gian
    final rawTime =
        widget.isTask ? widget.data['deadline'] : widget.data['start_time'];
    String dateStr = "N/A";
    String timeStr = "";
    if (rawTime != null) {
      final dt = DateTime.parse(rawTime).toLocal();
      dateStr = DateFormat('EEEE, d MMMM yyyy', settings.localeCode).format(dt);
      timeStr = DateFormat('HH:mm').format(dt);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isTask ? 'Chi tiết công việc' : 'Chi tiết sự kiện',
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textColor),
            onPressed: () => Navigator.pop(context,
                _isCompleted != (widget.data['is_completed'] ?? false)),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              onPressed: _isLoading ? null : _deleteItem,
            ),
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER CARD: Trạng thái & Loại ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTag(
                        widget.isTask ? 'TASK' : 'EVENT',
                        accentColor,
                      ),
                      if (widget.isTask) _buildStatusTag(_isCompleted),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- TITLE SECTION ---
                  Text(
                    widget.data['title'] ?? 'Không có tiêu đề',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- INFO CARD (Thời gian & Mô tả) ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hàng thời gian
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.calendar_today_rounded,
                                  color: accentColor, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  timeStr.isNotEmpty ? timeStr : '--:--',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: textColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: subTextColor,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Divider(color: subTextColor.withOpacity(0.2)),
                        const SizedBox(height: 24),

                        // Phần mô tả
                        Text(
                          'Mô tả',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: subTextColor),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (widget.data['description'] != null &&
                                  widget.data['description']
                                      .toString()
                                      .isNotEmpty)
                              ? widget.data['description']
                              : 'Không có mô tả chi tiết cho mục này.',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withOpacity(0.9),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      // --- BOTTOM ACTION BUTTON ---
      bottomNavigationBar: widget.isTask
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _toggleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isCompleted ? colorScheme.primary : accentColor,
                      elevation: 5,
                      shadowColor:
                          (_isCompleted ? colorScheme.primary : accentColor)
                              .withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isCompleted
                              ? Icons.restart_alt_rounded
                              : Icons.check_circle_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isCompleted
                              ? 'Đánh dấu chưa xong'
                              : 'Hoàn thành công việc',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        isDone ? 'COMPLETED' : 'IN PROGRESS',
        style: TextStyle(
          color: isDone ? Colors.green : Colors.orange,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
