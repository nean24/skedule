import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- BẢNG MÀU CHUẨN THEO THIẾT KẾ ---
class AppColors {
  static const Color scaffoldBg = Color(0xFFDDE3ED);
  static const Color cardBg = Colors.white;
  static const Color primaryBlue = Color(0xFF455A75);
  static const Color accentBlue = Color(0xFF7E97B8);
  static const Color textDark = Color(0xFF2D3142);
  static const Color textLight = Color(0xFF9094A6);

  static const Color work = Color(0xFFFF8A00);
  static const Color classColor = Color(0xFFA155FF);
  static const Color deadline = Color(0xFFFF4B4B);
  static const Color task = Color(0xFF00C566);
  static const Color todayChip = Color(0xFFE9EDF5);
  static const Color scheduleBlue = Color(0xFF3B82F6);
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _supabase = Supabase.instance.client;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  Map<DateTime, List<dynamic>> _eventsByDay = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDatabaseData();
  }

  Future<void> _fetchDatabaseData() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final eventsResponse = await _supabase.from('events').select().eq('user_id', user.id);
      final tasksResponse = await _supabase.from('tasks').select().eq('user_id', user.id);

      final Map<DateTime, List<dynamic>> newEventsByDay = {};

      for (var item in eventsResponse) {
        if (item['start_time'] != null) {
          final date = DateTime.parse(item['start_time']);
          final dayKey = DateTime(date.year, date.month, date.day);
          newEventsByDay.putIfAbsent(dayKey, () => []).add({...item, 'isTask': false});
        }
      }

      for (var item in tasksResponse) {
        if (item['deadline'] != null) {
          final date = DateTime.parse(item['deadline']);
          final dayKey = DateTime(date.year, date.month, date.day);
          newEventsByDay.putIfAbsent(dayKey, () => []).add({...item, 'isTask': true});
        }
      }

      setState(() {
        _eventsByDay = newEventsByDay;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildMonthNavigator(),
                    const SizedBox(height: 10),
                    _buildViewSwitcher(),
                    const SizedBox(height: 16),
                    _buildCalendarGrid(),
                    const SizedBox(height: 20),
                    _buildLegendChips(),
                    const SizedBox(height: 16),
                    _buildModeToggle(),
                    const SizedBox(height: 24),
                    _buildScheduleListFromData(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- GIẢI PHÁP 1: Sử dụng Flexible cho Header để tránh tràn ngang ---
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible( // Ngăn tiêu đề đẩy các nút ra khỏi màn hình
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: AppColors.primaryBlue, size: 28),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark), overflow: TextOverflow.ellipsis),
                      Text('Schedules', style: TextStyle(fontSize: 12, color: AppColors.textLight), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row( // Nút chức năng
            children: [
              _buildActionBtn(Icons.access_time, 'Templates', isOutlined: true),
              const SizedBox(width: 6),
              _buildActionBtn(Icons.add, 'Add', isOutlined: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, {required bool isOutlined}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : AppColors.accentBlue,
        borderRadius: BorderRadius.circular(20),
        border: isOutlined ? Border.all(color: AppColors.textLight.withOpacity(0.4)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isOutlined ? AppColors.textLight : Colors.white),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOutlined ? AppColors.textLight : Colors.white)),
        ],
      ),
    );
  }

  // --- GIẢI PHÁP 2: Loại bỏ SizedBox cố định ở bộ chọn tháng ---
  Widget _buildMonthNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
            icon: const Icon(Icons.chevron_left, color: AppColors.textLight)
        ),
        Expanded( // Sử dụng Expanded để chữ tự co giãn theo màn hình
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy').format(_focusedDay),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
            onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)),
            icon: const Icon(Icons.chevron_right, color: AppColors.textLight)
        ),
      ],
    );
  }

  Widget _buildViewSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildSwitchTab('Calendar', Icons.calendar_view_month, _calendarFormat == CalendarFormat.month, () {
            setState(() => _calendarFormat = CalendarFormat.month);
          }),
          _buildSwitchTab('Week', Icons.access_time, _calendarFormat == CalendarFormat.week, () {
            setState(() => _calendarFormat = CalendarFormat.week);
          }),
        ],
      ),
    );
  }

  Widget _buildSwitchTab(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : AppColors.textLight),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: TextStyle(color: isActive ? Colors.white : AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(8),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        headerVisible: false,
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) => setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _buildDayCard(day),
          selectedBuilder: (context, day, focusedDay) => _buildDayCard(day, isSelected: true),
          todayBuilder: (context, day, focusedDay) => _buildDayCard(day, isToday: true),
          markerBuilder: (context, day, events) {
            final normalizedDay = DateTime(day.year, day.month, day.day);
            final dayEvents = _eventsByDay[normalizedDay];
            if (dayEvents == null || dayEvents.isEmpty) return null;
            List<Color> markers = [];
            for (var e in dayEvents) {
              if (e['isTask'] == true) markers.add(AppColors.task);
              else {
                final type = e['type'].toString().toLowerCase();
                if (type == 'work') markers.add(AppColors.work);
                else if (type == 'class') markers.add(AppColors.classColor);
                else markers.add(AppColors.deadline);
              }
              if (markers.length >= 3) break;
            }
            return _buildDots(markers);
          },
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 12),
          weekendStyle: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDayCard(DateTime day, {bool isSelected = false, bool isToday = false}) {
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.scheduleBlue.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isToday ? AppColors.scheduleBlue : Colors.grey.shade100),
      ),
      child: Center(child: Text('${day.day}', style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? AppColors.scheduleBlue : AppColors.textDark, fontSize: 13))),
    );
  }

  Widget _buildDots(List<Color> colors) {
    return Positioned(
      bottom: 4, left: 0, right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: colors.map((c) => Container(margin: const EdgeInsets.symmetric(horizontal: 1), width: 4, height: 4, decoration: BoxDecoration(color: c, shape: BoxShape.circle))).toList(),
      ),
    );
  }

  Widget _buildLegendChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip('Work', AppColors.work),
          _buildChip('Class', AppColors.classColor),
          _buildChip('Deadline', AppColors.deadline),
          _buildChip('Task', AppColors.task),
          _buildChip('Today', AppColors.todayChip, textColor: AppColors.textDark),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color, {Color textColor = Colors.white}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildModeToggle() {
    return Row(
      children: [
        _buildModeBtn('Schedule', AppColors.scheduleBlue, true),
        const SizedBox(width: 8),
        _buildModeBtn('Note', AppColors.textLight.withOpacity(0.3), false),
      ],
    );
  }

  Widget _buildModeBtn(String label, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  // --- GIẢI PHÁP 3: Sử dụng IntrinsicHeight cho Schedule List ---
  Widget _buildScheduleListFromData() {
    final sortedDays = _eventsByDay.keys.toList()..sort();
    final filteredDays = sortedDays.where((day) => day.isAfter(_selectedDay!.subtract(const Duration(days: 1)))).take(3).toList();

    if (filteredDays.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: Text('No upcoming events', style: TextStyle(color: AppColors.textLight))),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: filteredDays.map((day) {
          final dayEvents = _eventsByDay[day]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildDayBlock(
              DateFormat('EEE').format(day).toUpperCase(),
              day.day.toString(),
              dayEvents.map((e) {
                Color color = AppColors.task;
                if (e['isTask'] == false) {
                  final type = e['type'].toString().toLowerCase();
                  if (type == 'work') color = AppColors.work;
                  else if (type == 'class') color = AppColors.classColor;
                  else color = AppColors.deadline;
                }
                return _buildEvent(e['title'] ?? 'Untitled', color);
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayBlock(String day, String date, List<Widget> events) {
    return IntrinsicHeight( // Giúp đường kẻ dọc tự động kéo dài theo nội dung bên phải
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 45,
            child: Column(
              children: [
                Text(day, style: const TextStyle(color: AppColors.textLight, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(date, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                Expanded(child: Container(width: 2, color: Colors.grey.shade200)), // Đường kẻ động
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(children: events)),
        ],
      ),
    );
  }

  Widget _buildEvent(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}