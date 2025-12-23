import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';

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

  // Dark Mode Colors
  static const Color scaffoldBgDark = Color(0xFF121212);
  static const Color cardBgDark = Color(0xFF1E1E1E);
  static const Color textDarkDark = Color(0xFFE0E0E0);
  static const Color textLightDark = Color(0xFFA0A0A0);
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
          final date = DateTime.parse(item['start_time']).toLocal();
          final dayKey = DateTime(date.year, date.month, date.day);
          newEventsByDay.putIfAbsent(dayKey, () => []).add({...item, 'isTask': false});
        }
      }

      for (var item in tasksResponse) {
        if (item['deadline'] != null) {
          final date = DateTime.parse(item['deadline']).toLocal();
          final dayKey = DateTime(date.year, date.month, date.day);
          newEventsByDay.putIfAbsent(dayKey, () => []).add({...item, 'isTask': true});
        }
      }

      setState(() {
        _eventsByDay = newEventsByDay;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC: HIỂN THỊ SHEET THÊM SỰ KIỆN ---
  void _showAddEventSheet(BuildContext context, {String? preTitle, String? preType, String? preDesc}) {
    final titleController = TextEditingController(text: preTitle ?? '');
    final descController = TextEditingController(text: preDesc ?? '');
    final noteController = TextEditingController();

    // Mặc định thời gian
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

    // Mặc định loại là 'task' (an toàn nhất)
    String selectedType = preType ?? 'task';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  const Text('Thêm sự kiện mới', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 20),

                  // Form Fields
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Chọn loại (UI hiển thị Work/Class/Task, nhưng logic bên dưới sẽ map lại)
                  Row(
                    children: [
                      Expanded(child: _buildTypeSelector('Work', 'work', selectedType, AppColors.work, (val) => setModalState(() => selectedType = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTypeSelector('Class', 'class', selectedType, AppColors.classColor, (val) => setModalState(() => selectedType = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTypeSelector('Task', 'task', selectedType, AppColors.task, (val) => setModalState(() => selectedType = val))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Chọn giờ
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(context: context, initialTime: startTime);
                            if (time != null) setModalState(() => startTime = time);
                          },
                          child: _buildTimeBox('Bắt đầu', startTime.format(context)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(context: context, initialTime: endTime);
                            if (time != null) setModalState(() => endTime = time);
                          },
                          child: _buildTimeBox('Kết thúc', endTime.format(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- TRƯỜNG NOTE ---
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú (Liên kết sự kiện)',
                      hintText: 'Nhập ghi chú nhanh...',
                      prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.primaryBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: AppColors.scaffoldBg.withOpacity(0.5),
                    ),
                  ),
                  const Spacer(),

                  // Nút Lưu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () async {
                        if (titleController.text.isEmpty) return;
                        await _saveEvent(
                            titleController.text,
                            descController.text,
                            noteController.text,
                            selectedType,
                            selectedDate,
                            startTime,
                            endTime
                        );
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Lưu sự kiện', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }

  // --- LOGIC: LƯU VÀO DATABASE (ĐÃ SỬA LỖI ENUM) ---
  Future<void> _saveEvent(String title, String desc, String note, String type, DateTime date, TimeOfDay start, TimeOfDay end) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final startDt = DateTime(date.year, date.month, date.day, start.hour, start.minute);
    final endDt = DateTime(date.year, date.month, date.day, end.hour, end.minute);

    // === QUAN TRỌNG: Mapping loại sự kiện để khớp với ENUM trong Database ===
    // Database chỉ chấp nhận: 'task', 'schedule', 'deadline' (và có thể 'workshift')
    // Nếu UI gửi 'work' hoặc 'class', ta map về 'schedule' để không bị lỗi.
    String dbType = type;
    if (type == 'work' || type == 'class') {
      dbType = 'schedule';
    }

    try {
      // 1. Insert Event
      final res = await _supabase.from('events').insert({
        'user_id': user.id,
        'title': title,
        'description': desc,
        'type': dbType, // Sử dụng dbType đã map
        'start_time': startDt.toIso8601String(),
        'end_time': endDt.toIso8601String(),
      }).select();

      // 2. Insert Note (Nếu có)
      if (note.isNotEmpty && res.isNotEmpty) {
        final eventId = res[0]['id'];
        await _supabase.from('notes').insert({
          'user_id': user.id,
          'content': note,
          'event_id': eventId,
        });
      }

      // 3. Insert Task (Chỉ khi chọn Task hoặc Deadline)
      if (type == 'task' || type == 'deadline') {
        await _supabase.from('tasks').insert({
          'user_id': user.id,
          'title': title,
          'description': desc,
          'deadline': endDt.toIso8601String(),
          'priority': 'medium',
          'status': 'todo',
          'event_id': res.isNotEmpty ? res[0]['id'] : null
        });
      }

      await _fetchDatabaseData(); // Reload data
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Widget _buildTypeSelector(String label, String value, String groupValue, Color color, Function(String) onTap) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
              label,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold
              )
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBox(String label, String time) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- LOGIC: HIỂN THỊ SHEET TEMPLATES ---
  void _showTemplatesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn mẫu nhanh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Lưu ý: type truyền vào đây phải map được ở hàm _saveEvent
            _buildTemplateItem(context, 'Họp Team', Icons.groups, 'work', 'Họp tiến độ dự án'),
            _buildTemplateItem(context, 'Tập Gym', Icons.fitness_center, 'task', 'Ngày tập chân'),
            _buildTemplateItem(context, 'Học bài', Icons.menu_book, 'class', 'Ôn thi cuối kỳ'),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateItem(BuildContext context, String title, IconData icon, String type, String desc) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.accentBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primaryBlue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
      onTap: () {
        Navigator.pop(context); // Đóng template sheet
        _showAddEventSheet(context, preTitle: title, preType: type, preDesc: desc);
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final bgColor = isDark ? AppColors.scaffoldBgDark : AppColors.scaffoldBg;
    final cardColor = isDark ? AppColors.cardBgDark : AppColors.cardBg;
    final textColor = isDark ? AppColors.textDarkDark : AppColors.textDark;
    final subTextColor = isDark ? AppColors.textLightDark : AppColors.textLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _buildHeader(settings, textColor, subTextColor),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildMonthNavigator(settings, textColor),
                    const SizedBox(height: 10),
                    _buildViewSwitcher(cardColor, subTextColor),
                    const SizedBox(height: 16),
                    _buildCalendarGrid(settings, cardColor, textColor, subTextColor),
                    const SizedBox(height: 20),
                    _buildLegendChips(textColor),
                    const SizedBox(height: 16),
                    _buildModeToggle(),
                    const SizedBox(height: 24),
                    _buildScheduleListFromData(settings, cardColor, textColor, subTextColor),
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

  Widget _buildHeader(SettingsProvider settings, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: AppColors.primaryBlue, size: 28),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(settings.strings.translate('calendar'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor), overflow: TextOverflow.ellipsis),
                      Text(settings.strings.translate('schedules'), style: TextStyle(fontSize: 12, color: subTextColor), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              _buildActionBtn(
                Icons.access_time,
                settings.strings.translate('templates'),
                isOutlined: true,
                textColor: subTextColor,
                onTap: () => _showTemplatesSheet(context),
              ),
              const SizedBox(width: 6),
              _buildActionBtn(
                Icons.add,
                'Add',
                isOutlined: false,
                textColor: Colors.white,
                onTap: () => _showAddEventSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, {required bool isOutlined, required Color textColor, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : AppColors.accentBlue,
          borderRadius: BorderRadius.circular(20),
          border: isOutlined ? Border.all(color: textColor.withOpacity(0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(SettingsProvider settings, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
            icon: const Icon(Icons.chevron_left, color: AppColors.textLight)
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy', settings.localeCode).format(_focusedDay),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
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

  Widget _buildViewSwitcher(Color cardColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildSwitchTab('Calendar', Icons.calendar_view_month, _calendarFormat == CalendarFormat.month, subTextColor, () {
            setState(() => _calendarFormat = CalendarFormat.month);
          }),
          _buildSwitchTab('Week', Icons.access_time, _calendarFormat == CalendarFormat.week, subTextColor, () {
            setState(() => _calendarFormat = CalendarFormat.week);
          }),
        ],
      ),
    );
  }

  Widget _buildSwitchTab(String label, IconData icon, bool isActive, Color subTextColor, VoidCallback onTap) {
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
              Icon(icon, size: 16, color: isActive ? Colors.white : subTextColor),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: TextStyle(color: isActive ? Colors.white : subTextColor, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(SettingsProvider settings, Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(8),
      child: TableCalendar(
        locale: settings.localeCode,
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        headerVisible: false,
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) => setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _buildDayCard(day, cardColor, textColor),
          selectedBuilder: (context, day, focusedDay) => _buildDayCard(day, cardColor, textColor, isSelected: true),
          todayBuilder: (context, day, focusedDay) => _buildDayCard(day, cardColor, textColor, isToday: true),
          markerBuilder: (context, day, events) {
            final normalizedDay = DateTime(day.year, day.month, day.day);
            final dayEvents = _eventsByDay[normalizedDay];
            if (dayEvents == null || dayEvents.isEmpty) return null;
            List<Color> markers = [];
            for (var e in dayEvents) {
              if (e['isTask'] == true) markers.add(AppColors.task);
              else {
                final type = e['type'].toString().toLowerCase();
                // Map logic màu sắc
                if (type == 'work' || type == 'workshift') markers.add(AppColors.work);
                else if (type == 'class') markers.add(AppColors.classColor);
                else if (type == 'schedule') markers.add(AppColors.scheduleBlue);
                else markers.add(AppColors.deadline);
              }
              if (markers.length >= 3) break;
            }
            return _buildDots(markers);
          },
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12),
          weekendStyle: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDayCard(DateTime day, Color cardColor, Color textColor, {bool isSelected = false, bool isToday = false}) {
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.scheduleBlue.withOpacity(0.1) : cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isToday ? AppColors.scheduleBlue : (isSelected ? Colors.transparent : Colors.grey.shade100.withOpacity(0.1))),
      ),
      child: Center(child: Text('${day.day}', style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? AppColors.scheduleBlue : textColor, fontSize: 13))),
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

  Widget _buildLegendChips(Color textColor) {
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

  Widget _buildScheduleListFromData(SettingsProvider settings, Color cardColor, Color textColor, Color subTextColor) {
    final sortedDays = _eventsByDay.keys.toList()..sort();
    final filteredDays = sortedDays.where((day) => day.isAfter(_selectedDay!.subtract(const Duration(days: 1)))).take(3).toList();

    if (filteredDays.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
        child: Center(child: Text(settings.strings.translate('no_upcoming_events'), style: TextStyle(color: subTextColor))),
      );
    }

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: filteredDays.map((day) {
          final dayEvents = _eventsByDay[day]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildDayBlock(
                DateFormat('EEE', settings.localeCode).format(day).toUpperCase(),
                day.day.toString(),
                dayEvents.map((e) {
                  Color color = AppColors.task;
                  if (e['isTask'] == false) {
                    final type = e['type'].toString().toLowerCase();
                    if (type == 'work') color = AppColors.work;
                    else if (type == 'class') color = AppColors.classColor;
                    else if (type == 'schedule') color = AppColors.scheduleBlue;
                    else color = AppColors.deadline;
                  }
                  return _buildEvent(e['title'] ?? 'Untitled', color, textColor);
                }).toList(),
                textColor,
                subTextColor
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayBlock(String day, String date, List<Widget> events, Color textColor, Color subTextColor) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 45,
            child: Column(
              children: [
                Text(day, style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(date, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
                Expanded(child: Container(width: 2, color: Colors.grey.shade200)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(children: events)),
        ],
      ),
    );
  }

  Widget _buildEvent(String title, Color color, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: textColor), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}