import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';
import 'package:skedule/widgets/stat_card.dart';
import 'package:skedule/widgets/task_card.dart';
import 'package:skedule/home/screens/event_detail_screen.dart';
import 'package:skedule/home/screens/help_screen.dart'; // <--- Đã thêm import trang Help

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Các biến dữ liệu thống kê
  int _completedTasks = 0;
  int _happeningNow = 0;
  int _missedCount = 0;
  int _dayStreak = 0;
  double _productivityScore = 0.0;

  // Danh sách hiển thị
  List<Map<String, dynamic>> _comingUpItems = [];
  List<Map<String, dynamic>> _missedTasksItems = [];

  // Thống kê tuần
  int _weekCompleted = 0;
  int _weekActiveDays = 0;
  int _weekUpcoming = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    try {
      // 1. Lấy dữ liệu Tasks
      final tasksResponse =
          await _supabase.from('tasks').select().eq('user_id', user.id);

      // 2. Lấy dữ liệu Events
      final eventsResponse =
          await _supabase.from('events').select().eq('user_id', user.id);

      int completed = 0;
      int missed = 0;
      int weekComp = 0;
      int weekUp = 0;

      List<Map<String, dynamic>> comingUp = [];
      List<Map<String, dynamic>> missedList = [];

      // Tập hợp các ngày đã hoàn thành task để tính Streak
      final Set<DateTime> activeDates = {};

      // --- XỬ LÝ TASKS ---
      for (var t in tasksResponse) {
        final task = Map<String, dynamic>.from(t);
        task['isTask'] = true; // Đánh dấu đây là Task

        final bool isCompleted = task['is_completed'] ?? false;
        final DateTime? deadline = task['deadline'] != null
            ? DateTime.parse(task['deadline']).toLocal()
            : null;

        if (isCompleted) {
          completed++;
          if (deadline != null && deadline.isAfter(startOfWeek)) weekComp++;

          // Lưu ngày hoàn thành để tính Streak
          if (task['updated_at'] != null) {
            final updateTime = DateTime.parse(task['updated_at']).toLocal();
            activeDates.add(
                DateTime(updateTime.year, updateTime.month, updateTime.day));
          }
        } else if (deadline != null) {
          if (deadline.isBefore(now)) {
            missed++;
            missedList.add(task);
          } else {
            comingUp.add(task);
            if (deadline.isAfter(startOfWeek)) weekUp++;
          }
        } else {
          // Task chưa xong và không có deadline -> cho vào danh sách cần làm
          comingUp.add(task);
        }
      }

      // --- TÍNH TOÁN STREAK ---
      int streak = 0;
      DateTime checkDate = today;
      // Nếu hôm nay chưa làm, kiểm tra từ hôm qua để giữ chuỗi
      if (!activeDates.contains(today)) {
        checkDate = today.subtract(const Duration(days: 1));
      }
      while (activeDates.contains(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      // --- XỬ LÝ EVENTS ---
      int happening = 0;
      for (var e in eventsResponse) {
        final event = Map<String, dynamic>.from(e);
        event['isTask'] = false; // Đánh dấu đây là Event

        if (event['start_time'] == null || event['end_time'] == null) continue;

        final startTime = DateTime.parse(event['start_time']).toLocal();
        final endTime = DateTime.parse(event['end_time']).toLocal();

        if (startTime.isBefore(now) && endTime.isAfter(now)) {
          happening++;
        } else if (startTime.isAfter(now)) {
          comingUp.add(event);
        }
      }

      // Sắp xếp danh sách Coming Up theo thời gian
      comingUp.sort((a, b) {
        DateTime timeA = DateTime(2100);
        if (a['isTask'] == true && a['deadline'] != null) {
          timeA = DateTime.parse(a['deadline']).toLocal();
        } else if (a['isTask'] == false && a['start_time'] != null) {
          timeA = DateTime.parse(a['start_time']).toLocal();
        }

        DateTime timeB = DateTime(2100);
        if (b['isTask'] == true && b['deadline'] != null) {
          timeB = DateTime.parse(b['deadline']).toLocal();
        } else if (b['isTask'] == false && b['start_time'] != null) {
          timeB = DateTime.parse(b['start_time']).toLocal();
        }
        return timeA.compareTo(timeB);
      });

      // Tính điểm hiệu suất
      double score = tasksResponse.isEmpty
          ? 0.0
          : (completed / tasksResponse.length) * 100;

      if (mounted) {
        setState(() {
          _completedTasks = completed;
          _happeningNow = happening;
          _missedCount = missed;
          _dayStreak = streak;
          _productivityScore = score;

          _comingUpItems = comingUp.take(3).toList(); // Lấy 3 việc sắp tới
          _missedTasksItems = missedList.take(3).toList();

          _weekCompleted = weekComp;
          _weekUpcoming = weekUp;
          _weekActiveDays =
              activeDates.where((d) => d.isAfter(startOfWeek)).length;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi Dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hàm chuyển trang khi bấm vào Task/Event
  void _navigateToDetail(Map<String, dynamic> item, bool isTask) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(
          data: item,
          isTask: isTask,
        ),
      ),
    );

    // Nếu màn hình chi tiết trả về true (có thay đổi dữ liệu), load lại dashboard
    if (result == true) {
      _fetchDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = colorScheme.background;
    final cardColor = colorScheme.surface;
    final textColor = colorScheme.onSurface;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        children: [
          _buildHeader(cardColor, textColor, subTextColor),
          const SizedBox(height: 24),
          _buildStatsGrid(settings),
          const SizedBox(height: 32),

          // --- COMING UP ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildSectionHeader(
                title: settings.strings.translate('coming_up')),
          ),
          const SizedBox(height: 16),
          _buildComingUpList(),

          const SizedBox(height: 24),

          // --- MISSED TASKS ---
          if (_missedTasksItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSectionHeader(
                  title: settings.strings.translate('missed_tasks'),
                  count: _missedCount),
            ),
            const SizedBox(height: 16),
            _buildMissedTasksList(),
            const SizedBox(height: 32),
          ],

          _buildSummaryCard(settings),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- CÁC WIDGET CON ---

  Widget _buildHeader(Color cardColor, Color textColor, Color subTextColor) {
    final settings = Provider.of<SettingsProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.strings.translate('dashboard'),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textColor),
                ),
                Text(
                  DateFormat('EEEE, MMM d', settings.localeCode)
                      .format(DateTime.now()),
                  style: TextStyle(color: subTextColor, fontSize: 14),
                ),
              ],
            ),
          ),

          // --- NÚT HƯỚNG DẪN (DẤU ?) MỚI THÊM ---
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04), blurRadius: 10)
                ],
              ),
              child: Icon(Icons.help_outline_rounded,
                  color: subTextColor, size: 24),
            ),
          ),
          // ----------------------------------------

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${_productivityScore.toInt()}%',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6)),
                ),
                Text(settings.strings.translate('score'),
                    style: TextStyle(
                        color: subTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatsGrid(SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
        children: [
          StatCard(
              label: settings.strings.translate('completed'),
              value: '$_completedTasks',
              icon: Icons.check_circle_outline,
              iconColor: Colors.blue),
          StatCard(
              label: settings.strings.translate('active'),
              value: '$_happeningNow',
              icon: Icons.bolt,
              iconColor: Colors.purple),
          StatCard(
              label: settings.strings.translate('missed'),
              value: '$_missedCount',
              icon: Icons.error_outline,
              iconColor: Colors.redAccent),
          StatCard(
              label: settings.strings.translate('streak'),
              value: '$_dayStreak',
              icon: Icons.local_fire_department_outlined,
              iconColor: Colors.orange),
        ],
      ),
    );
  }

  Widget _buildComingUpList() {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final timeFormat = settings.is24HourFormat ? 'HH:mm' : 'hh:mm a';
    final emptyTextColor = isDark ? Colors.grey[400] : const Color(0xFF9094A6);

    if (_comingUpItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(settings.strings.translate('no_schedule_upcoming'),
            style: TextStyle(color: emptyTextColor)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: _comingUpItems.map((item) {
          final bool isTask = item['isTask'];

          String timeStr = "--:--";
          if (isTask && item['deadline'] != null) {
            timeStr = DateFormat(timeFormat)
                .format(DateTime.parse(item['deadline']).toLocal());
          } else if (!isTask && item['start_time'] != null) {
            timeStr = DateFormat(timeFormat)
                .format(DateTime.parse(item['start_time']).toLocal());
          }

          return TaskCard(
            title: item['title'] ?? 'Untitled',
            subtitle: isTask ? 'Task' : 'Event',
            time: timeStr,
            location: isTask ? '' : (item['description'] ?? ''),
            tag1Text: isTask ? 'deadline' : item['type'] ?? 'event',
            tag1Color: isTask ? Colors.orange : Colors.purple,
            tag2Text: isTask ? (item['priority'] ?? '') : '',
            tag2Color: Colors.redAccent,
            icon: isTask ? Icons.task_alt : Icons.event,
            borderColor: isTask ? Colors.orange : Colors.purple,
            isTask: isTask,
            onTap: () => _navigateToDetail(item, isTask),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMissedTasksList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: _missedTasksItems.map((item) {
          return TaskCard(
            title: item['title'] ?? 'N/A',
            subtitle: 'Overdue',
            time: 'Missed',
            location: '',
            tag1Text: 'high',
            tag1Color: Colors.red,
            tag2Text: '',
            tag2Color: Colors.transparent,
            icon: Icons.error_outline,
            borderColor: Colors.red,
            isTask: true,
            onTap: () => _navigateToDetail(item, true),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCard(SettingsProvider settings) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = colorScheme.surface;
    final textColor = colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(settings.strings.translate('this_week_summary'),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('$_weekCompleted',
                    settings.strings.translate('completed'), textColor),
                _summaryItem('$_weekActiveDays',
                    settings.strings.translate('active'), textColor),
                _summaryItem('$_weekUpcoming',
                    settings.strings.translate('upcoming'), textColor),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color textColor) {
    final labelColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
        Text(label,
            style: TextStyle(
                color: labelColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, int? count}) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(width: 10),
        if (count != null && count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          )
      ],
    );
  }
}
