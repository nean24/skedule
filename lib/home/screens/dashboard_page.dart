import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/widgets/stat_card.dart';
import 'package:skedule/widgets/task_card.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Biến thống kê
  int _completedTasks = 0;
  int _happeningNow = 0;
  int _missedCount = 0;
  int _dayStreak = 0; // Để tạm là 0, cần logic phức tạp hơn để tính streak thật
  double _productivityScore = 0.0;

  // Danh sách hiển thị
  List<dynamic> _comingUpItems = [];
  List<dynamic> _missedTasksItems = [];

  // Thống kê tuần
  int _weekCompleted = 0;
  int _weekActiveDays = 1; // Giá trị mặc định
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
    // Tính ngày đầu tuần (Thứ 2)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    try {
      // Lấy dữ liệu từ 2 bảng
      final tasksResponse =
          await _supabase.from('tasks').select().eq('user_id', user.id);
      final eventsResponse =
          await _supabase.from('events').select().eq('user_id', user.id);

      int completed = 0;
      int missed = 0;
      List<dynamic> comingUp = [];
      List<dynamic> missedList = [];
      int weekComp = 0;
      int weekUp = 0;

      // Xử lý Tasks
      for (var t in tasksResponse) {
        // Tạo bản sao để có thể chỉnh sửa (thêm field isTask)
        final task = Map<String, dynamic>.from(t);

        final bool isCompleted = task['is_completed'] ?? false;
        final DateTime? deadline = task['deadline'] != null
            ? DateTime.parse(task['deadline']).toLocal()
            : null;

        if (isCompleted) {
          completed++;
          if (deadline != null && deadline.isAfter(startOfWeek)) weekComp++;
        } else if (deadline != null) {
          if (deadline.isBefore(now)) {
            missed++;
            task['isTask'] = true;
            missedList.add(task);
          } else {
            task['isTask'] = true;
            comingUp.add(task);
            if (deadline.isAfter(startOfWeek)) weekUp++;
          }
        } else {
          // Task không có deadline nhưng chưa xong
          task['isTask'] = true;
          comingUp.add(task);
        }
      }

      // Xử lý Events
      int happening = 0;
      for (var e in eventsResponse) {
        final event = Map<String, dynamic>.from(e);

        if (event['start_time'] == null || event['end_time'] == null) continue;

        final startTime = DateTime.parse(event['start_time']).toLocal();
        final endTime = DateTime.parse(event['end_time']).toLocal();

        if (startTime.isBefore(now) && endTime.isAfter(now)) {
          happening++;
        } else if (startTime.isAfter(now)) {
          event['isTask'] = false;
          comingUp.add(event);
        }
      }

      // Sắp xếp danh sách Coming Up theo thời gian
      comingUp.sort((a, b) {
        DateTime timeA;
        if (a['isTask'] == true && a['deadline'] != null) {
          timeA = DateTime.parse(a['deadline']).toLocal();
        } else if (a['start_time'] != null) {
          timeA = DateTime.parse(a['start_time']).toLocal();
        } else {
          timeA = DateTime(2100); // Đẩy xuống cuối nếu không có ngày
        }

        DateTime timeB;
        if (b['isTask'] == true && b['deadline'] != null) {
          timeB = DateTime.parse(b['deadline']).toLocal();
        } else if (b['start_time'] != null) {
          timeB = DateTime.parse(b['start_time']).toLocal();
        } else {
          timeB = DateTime(2100);
        }

        return timeA.compareTo(timeB);
      });

      // Tính điểm hiệu suất đơn giản
      double score = tasksResponse.isEmpty
          ? 0.0
          : (completed / tasksResponse.length) * 100;

      if (mounted) {
        setState(() {
          _completedTasks = completed;
          _happeningNow = happening;
          _missedCount = missed;
          _productivityScore = score;
          _comingUpItems = comingUp.take(5).toList(); // Lấy 5 việc sắp tới
          _missedTasksItems = missedList.take(3).toList();
          _weekCompleted = weekComp;
          _weekUpcoming = weekUp;
          _weekActiveDays = 1; // Tạm thời để 1
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi Dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStatsGrid(settings),
          const SizedBox(height: 32),

          // Coming Up Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildSectionHeader(
                title: settings.strings.translate('coming_up')),
          ),
          const SizedBox(height: 16),
          _buildComingUpList(),

          const SizedBox(height: 24),

          // Missed Tasks Section
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

  Widget _buildHeader() {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3142);
    final subTextColor = isDark ? Colors.grey[400] : const Color(0xFF9094A6);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

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

          String timeStr = "";
          if (isTask && item['deadline'] != null) {
            timeStr = DateFormat(timeFormat)
                .format(DateTime.parse(item['deadline']).toLocal());
          } else if (!isTask && item['start_time'] != null) {
            timeStr = DateFormat(timeFormat)
                .format(DateTime.parse(item['start_time']).toLocal());
          } else {
            timeStr = "No time";
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
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCard(SettingsProvider settings) {
    final isDark = settings.isDarkMode;
    final cardColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE2E6EE);
    final textColor = isDark ? Colors.white : const Color(0xFF2D3142);

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
                    settings.strings.translate('completed'), isDark),
                _summaryItem('$_weekActiveDays',
                    settings.strings.translate('active'), isDark),
                _summaryItem('$_weekUpcoming',
                    settings.strings.translate('upcoming'), isDark),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String value, String label, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF2D3142);
    final labelColor = isDark ? Colors.grey[400] : const Color(0xFF9094A6);

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
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3142);

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
