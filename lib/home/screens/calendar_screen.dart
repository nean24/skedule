import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';

// --- BẢNG MÀU ---
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
  static const Color workshift = Color(0xFF00B8D9);
  static const Color todayChip = Color(0xFFE9EDF5);
  static const Color scheduleBlue = Color(0xFF3B82F6);

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

  // --- HÀM LẤY DỮ LIỆU TỪ DB (FIX LỖI NULL AN TOÀN) ---
  Future<void> _fetchDatabaseData() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final eventsResponse =
          await _supabase.from('events').select().eq('user_id', user.id);
      final tasksResponse =
          await _supabase.from('tasks').select().eq('user_id', user.id);

      final Map<DateTime, List<dynamic>> newEventsByDay = {};

      for (var item in eventsResponse) {
        if (item['start_time'] != null) {
          final date = DateTime.parse(item['start_time']).toLocal();
          final dayKey = DateTime(date.year, date.month, date.day);

          // SỬA LỖI: Dùng where().isNotEmpty để tránh lỗi firstWhere orElse null
          final matchingTasks =
              tasksResponse.where((t) => t['event_id'] == item['id']);
          final relatedTask =
              matchingTasks.isNotEmpty ? matchingTasks.first : null;

          newEventsByDay.putIfAbsent(dayKey, () => []).add({
            ...item,
            'isTask': ['task', 'deadline'].contains(item['type']),
            'priority': relatedTask != null ? relatedTask['priority'] : null,
          });
        }
      }

      setState(() {
        _eventsByDay = newEventsByDay;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // --- FORM THÊM MỚI (FIX LỖI CÚ PHÁP) ---
  // ===========================================================================
  Future<void> _showAddEventSheet(BuildContext context,
      {String? preTitle, String? preType, String? preDesc}) async {
    final titleController = TextEditingController(text: preTitle ?? '');
    final descController = TextEditingController(text: preDesc ?? '');
    final noteController = TextEditingController();
    final tagController = TextEditingController();

    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime =
        TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

    String selectedType = preType ?? 'Task';
    String selectedPriority = 'medium';
    List<String> selectedTags = [];

    final List<String> eventTypes = [
      'Task',
      'Schedule',
      'Workshift',
      'Deadline',
      'Custom'
    ];
    final List<String> priorities = ['low', 'medium', 'high'];

    final bool? shouldRefresh = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // SỬA: Dùng block { return ... } để rõ ràng, tránh lỗi parser
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Logic hiển thị động
            bool showTaskFields =
                ['Task', 'Deadline', 'Custom'].contains(selectedType);
            bool showTagInput = selectedType == 'Custom';

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thêm sự kiện mới',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                        Icon(_getIconForType(selectedType),
                            color: AppColors.primaryBlue, size: 28),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 1. Loại sự kiện
                    DropdownButtonFormField<String>(
                      value: eventTypes.contains(selectedType)
                          ? selectedType
                          : 'Task',
                      decoration: InputDecoration(
                        labelText: 'Loại sự kiện',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon:
                            const Icon(Icons.category, color: Colors.grey),
                      ),
                      items: eventTypes
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 12),

                    // 2. Tiêu đề
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Tiêu đề',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. Thời gian
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030));
                              if (picked != null)
                                setModalState(() => selectedDate = picked);
                            },
                            child: _buildTimeBox('Ngày',
                                DateFormat('dd/MM').format(selectedDate)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                  context: context, initialTime: startTime);
                              if (time != null)
                                setModalState(() => startTime = time);
                            },
                            child: _buildTimeBox(
                                'Bắt đầu', startTime.format(context)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                  context: context, initialTime: endTime);
                              if (time != null)
                                setModalState(() => endTime = time);
                            },
                            child: _buildTimeBox(
                                'Kết thúc', endTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 4. Priority (Task/Deadline/Custom)
                    if (showTaskFields) ...[
                      DropdownButtonFormField<String>(
                        value: selectedPriority,
                        decoration: InputDecoration(
                          labelText: 'Độ ưu tiên',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon:
                              const Icon(Icons.flag, color: Colors.orange),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: priorities
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(p.toUpperCase())))
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedPriority = val!),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 5. Tags Custom
                    if (showTagInput) ...[
                      TextField(
                        controller: tagController,
                        decoration: InputDecoration(
                          labelText: 'Nhập Tag (Rồi bấm +)',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: AppColors.primaryBlue),
                            onPressed: () {
                              if (tagController.text.isNotEmpty) {
                                setModalState(() {
                                  selectedTags.add(tagController.text.trim());
                                  tagController.clear();
                                });
                              }
                            },
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onSubmitted: (val) {
                          if (val.isNotEmpty) {
                            setModalState(() {
                              selectedTags.add(val.trim());
                              tagController.clear();
                            });
                          }
                        },
                      ),
                      if (selectedTags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            children: selectedTags
                                .map((t) => Chip(
                                      label: Text(t),
                                      backgroundColor:
                                          AppColors.accentBlue.withOpacity(0.2),
                                      onDeleted: () => setModalState(
                                          () => selectedTags.remove(t)),
                                    ))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

                    // 6. Mô tả & Ghi chú
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Mô tả',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú (Note)',
                        prefixIcon: const Icon(Icons.note_alt_outlined,
                            color: AppColors.primaryBlue),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.scaffoldBg.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nút Lưu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () async {
                          if (titleController.text.isEmpty) return;
                          await _saveEventToDB(
                              title: titleController.text,
                              desc: descController.text,
                              note: noteController.text,
                              uiType: selectedType,
                              priority: selectedPriority,
                              tags: selectedTags,
                              date: selectedDate,
                              start: startTime,
                              end: endTime);
                          if (mounted) Navigator.pop(context, true);
                        },
                        child: const Text('Lưu sự kiện',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldRefresh == true) _fetchDatabaseData();
  }

  // --- LOGIC LƯU DB ---
  Future<void> _saveEventToDB(
      {required String title,
      required String desc,
      required String note,
      required String uiType,
      required String priority,
      required List<String> tags,
      required DateTime date,
      required TimeOfDay start,
      required TimeOfDay end}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final startDt =
        DateTime(date.year, date.month, date.day, start.hour, start.minute);
    final endDt =
        DateTime(date.year, date.month, date.day, end.hour, end.minute);

    String dbType = 'task';
    bool shouldCreateTask = false;

    switch (uiType.toLowerCase()) {
      case 'schedule':
        dbType = 'schedule';
        break;
      case 'workshift':
        dbType = 'workshift';
        break;
      case 'deadline':
        dbType = 'deadline';
        shouldCreateTask = true;
        break;
      case 'task':
        dbType = 'task';
        shouldCreateTask = true;
        break;
      case 'custom':
        dbType = 'task';
        shouldCreateTask = true;
        break;
    }

    try {
      final resEvent = await _supabase
          .from('events')
          .insert({
            'user_id': user.id,
            'title': title,
            'description': desc,
            'type': dbType,
            'start_time': startDt.toIso8601String(),
            'end_time': endDt.toIso8601String(),
          })
          .select()
          .single();
      final eventId = resEvent['id'];

      if (note.isNotEmpty) {
        await _supabase
            .from('notes')
            .insert({'user_id': user.id, 'content': note, 'event_id': eventId});
      }

      if (shouldCreateTask) {
        final resTask = await _supabase
            .from('tasks')
            .insert({
              'user_id': user.id,
              'event_id': eventId,
              'title': title,
              'description': desc,
              'priority': priority,
              'status': 'todo',
              'deadline': endDt.toIso8601String(),
            })
            .select()
            .single();
        final taskId = resTask['id'];

        if (tags.isNotEmpty) {
          for (String tagName in tags) {
            var tagRes = await _supabase
                .from('tags')
                .select()
                .eq('name', tagName)
                .eq('user_id', user.id)
                .maybeSingle();
            dynamic tagId = tagRes != null
                ? tagRes['id']
                : (await _supabase
                    .from('tags')
                    .insert({'user_id': user.id, 'name': tagName})
                    .select()
                    .single())['id'];
            await _supabase
                .from('task_tags')
                .insert({'task_id': taskId, 'tag_id': tagId});
          }
        }
      } else if (dbType == 'schedule' || dbType == 'workshift') {
        // Logic schedule nếu cần
      }
    } catch (e) {
      debugPrint('DB Error: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // --- HELPER UI ---
  IconData _getIconForType(String type) {
    switch (type) {
      case 'Workshift':
        return Icons.badge;
      case 'Schedule':
        return Icons.calendar_month;
      case 'Task':
        return Icons.check_circle_outline;
      case 'Deadline':
        return Icons.timer_off;
      case 'Custom':
        return Icons.edit_note;
      default:
        return Icons.event;
    }
  }

  Widget _buildTimeBox(String label, String time) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(time,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showTemplatesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn mẫu nhanh',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTemplateItem(context, 'Họp Team', Icons.groups, 'Schedule',
                'Họp tiến độ dự án'),
            _buildTemplateItem(context, 'Tập Gym', Icons.fitness_center, 'Task',
                'Ngày tập chân'),
            _buildTemplateItem(
                context, 'Ca Sáng', Icons.badge, 'Workshift', '8:00 - 12:00'),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateItem(BuildContext context, String title, IconData icon,
      String type, String desc) {
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.primaryBlue)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
      onTap: () {
        Navigator.pop(context);
        _showAddEventSheet(context,
            preTitle: title, preType: type, preDesc: desc);
      },
    );
  }

  // --- GIAO DIỆN CHÍNH (GIỮ NGUYÊN) ---
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
                          _buildCalendarGrid(
                              settings, cardColor, textColor, subTextColor),
                          const SizedBox(height: 20),
                          _buildLegendChips(textColor),
                          const SizedBox(height: 16),
                          _buildModeToggle(),
                          const SizedBox(height: 24),
                          _buildScheduleListFromData(
                              settings, cardColor, textColor, subTextColor),
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

  Widget _buildHeader(
      SettingsProvider settings, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: AppColors.primaryBlue, size: 28),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(settings.strings.translate('calendar'),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textColor),
                          overflow: TextOverflow.ellipsis),
                      Text(settings.strings.translate('schedules'),
                          style: TextStyle(fontSize: 12, color: subTextColor),
                          overflow: TextOverflow.ellipsis),
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
                onTap: () async {
                  await _showAddEventSheet(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label,
      {required bool isOutlined,
      required Color textColor,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : AppColors.accentBlue,
          borderRadius: BorderRadius.circular(20),
          border:
              isOutlined ? Border.all(color: textColor.withOpacity(0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
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
            onPressed: () => setState(() => _focusedDay =
                DateTime(_focusedDay.year, _focusedDay.month - 1)),
            icon: const Icon(Icons.chevron_left, color: AppColors.textLight)),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy', settings.localeCode).format(_focusedDay),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
            onPressed: () => setState(() => _focusedDay =
                DateTime(_focusedDay.year, _focusedDay.month + 1)),
            icon: const Icon(Icons.chevron_right, color: AppColors.textLight)),
      ],
    );
  }

  Widget _buildViewSwitcher(Color cardColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildSwitchTab('Calendar', Icons.calendar_view_month,
              _calendarFormat == CalendarFormat.month, subTextColor, () {
            setState(() => _calendarFormat = CalendarFormat.month);
          }),
          _buildSwitchTab('Week', Icons.access_time,
              _calendarFormat == CalendarFormat.week, subTextColor, () {
            setState(() => _calendarFormat = CalendarFormat.week);
          }),
        ],
      ),
    );
  }

  Widget _buildSwitchTab(String label, IconData icon, bool isActive,
      Color subTextColor, VoidCallback onTap) {
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
              Icon(icon,
                  size: 16, color: isActive ? Colors.white : subTextColor),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(label,
                      style: TextStyle(
                          color: isActive ? Colors.white : subTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(SettingsProvider settings, Color cardColor,
      Color textColor, Color subTextColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
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
        onDaySelected: (selectedDay, focusedDay) => setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        }),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) =>
              _buildDayCard(day, cardColor, textColor),
          selectedBuilder: (context, day, focusedDay) =>
              _buildDayCard(day, cardColor, textColor, isSelected: true),
          todayBuilder: (context, day, focusedDay) =>
              _buildDayCard(day, cardColor, textColor, isToday: true),
          markerBuilder: (context, day, events) {
            final normalizedDay = DateTime(day.year, day.month, day.day);
            final dayEvents = _eventsByDay[normalizedDay];
            if (dayEvents == null || dayEvents.isEmpty) return null;
            List<Color> markers = [];
            for (var e in dayEvents) {
              if (e['isTask'] == true)
                markers.add(AppColors.task);
              else {
                final type = e['type'].toString().toLowerCase();
                if (type == 'work' || type == 'workshift')
                  markers.add(AppColors.work);
                else if (type == 'class')
                  markers.add(AppColors.classColor);
                else if (type == 'schedule')
                  markers.add(AppColors.scheduleBlue);
                else
                  markers.add(AppColors.deadline);
              }
              if (markers.length >= 3) break;
            }
            return _buildDots(markers);
          },
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
              color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12),
          weekendStyle: TextStyle(
              color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDayCard(DateTime day, Color cardColor, Color textColor,
      {bool isSelected = false, bool isToday = false}) {
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.scheduleBlue.withOpacity(0.1) : cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isToday
                ? AppColors.scheduleBlue
                : (isSelected
                    ? Colors.transparent
                    : Colors.grey.shade100.withOpacity(0.1))),
      ),
      child: Center(
          child: Text('${day.day}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isToday ? AppColors.scheduleBlue : textColor,
                  fontSize: 13))),
    );
  }

  Widget _buildDots(List<Color> colors) {
    return Positioned(
      bottom: 4,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: colors
            .map((c) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)))
            .toList(),
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
          _buildChip('Today', AppColors.todayChip,
              textColor: AppColors.textDark),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color,
      {Color textColor = Colors.white}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildScheduleListFromData(SettingsProvider settings, Color cardColor,
      Color textColor, Color subTextColor) {
    final sortedDays = _eventsByDay.keys.toList()..sort();
    final filteredDays = sortedDays
        .where((day) =>
            day.isAfter(_selectedDay!.subtract(const Duration(days: 1))))
        .take(3)
        .toList();

    if (filteredDays.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cardColor, borderRadius: BorderRadius.circular(20)),
        child: Center(
            child: Text(settings.strings.translate('no_upcoming_events'),
                style: TextStyle(color: subTextColor))),
      );
    }

    return Container(
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: filteredDays.map((day) {
          final dayEvents = _eventsByDay[day]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildDayBlock(
                DateFormat('EEE', settings.localeCode)
                    .format(day)
                    .toUpperCase(),
                day.day.toString(),
                dayEvents.map((e) {
                  Color color = AppColors.task;
                  if (e['isTask'] == false) {
                    final type = e['type'].toString().toLowerCase();
                    if (type == 'work')
                      color = AppColors.work;
                    else if (type == 'class')
                      color = AppColors.classColor;
                    else if (type == 'schedule')
                      color = AppColors.scheduleBlue;
                    else
                      color = AppColors.deadline;
                  }
                  return _buildEvent(
                      e['title'] ?? 'Untitled', color, textColor);
                }).toList(),
                textColor,
                subTextColor),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayBlock(String day, String date, List<Widget> events,
      Color textColor, Color subTextColor) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 45,
            child: Column(
              children: [
                Text(day,
                    style: TextStyle(
                        color: subTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Text(date,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor)),
                Expanded(
                    child: Container(width: 2, color: Colors.grey.shade200)),
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
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: textColor),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
