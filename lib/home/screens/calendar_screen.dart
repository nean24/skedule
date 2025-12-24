import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';
import 'package:skedule/home/screens/event_detail_screen.dart';

// --- BẢNG MÀU DÙNG RIÊNG CHO CÁC LOẠI SỰ KIỆN ---
// Các màu nền/chữ chính sẽ lấy từ Theme.of(context)
class EventColors {
  static const Color work = Color(0xFFFF8A00);
  static const Color classColor = Color(0xFFA155FF);
  static const Color deadline = Color(0xFFFF4B4B);
  static const Color task = Color(0xFF00C566);
  static const Color scheduleBlue = Color(0xFF3B82F6);
  static const Color todayChip = Color(0xFFE9EDF5);

  // Màu phụ trợ
  static const Color accentBlue = Color(0xFF7E97B8);
  static const Color primaryBlue = Color(0xFF455A75);
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

  // --- LOGIC: LẤY DỮ LIỆU TỪ DB (GIỮ NGUYÊN LOGIC FIX) ---
  Future<void> _fetchDatabaseData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Lấy Events và Tasks song song
      final eventsResponse =
          await _supabase.from('events').select().eq('user_id', user.id);
      final tasksResponse =
          await _supabase.from('tasks').select().eq('user_id', user.id);

      final Map<DateTime, List<dynamic>> newEventsByDay = {};

      for (var item in eventsResponse) {
        if (item['start_time'] != null) {
          final date = DateTime.parse(item['start_time']).toLocal();
          final dayKey = DateTime(date.year, date.month, date.day);

          // Tìm task liên quan để lấy độ ưu tiên (nếu có)
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

      if (mounted) {
        setState(() {
          _eventsByDay = newEventsByDay;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching calendar data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // --- UI & LOGIC: FORM THÊM MỚI (DUNG HỢP THEME + LOGIC) ---
  // ===========================================================================
  Future<void> _showAddEventSheet(BuildContext context,
      {String? preTitle, String? preType, String? preDesc}) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    // Lấy màu từ Theme (Chuẩn nhánh dev_nean24)
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final inputDecorationTheme = theme.inputDecorationTheme;

    final titleController = TextEditingController(text: preTitle ?? '');
    final descController = TextEditingController(text: preDesc ?? '');
    final noteController = TextEditingController();
    final tagController = TextEditingController();
    final checklistController = TextEditingController();

    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime =
        TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

    // Map ngôn ngữ cho loại sự kiện
    String selectedType = preType ?? settings.strings.translate('task');
    String selectedPriority = 'medium';
    List<String> selectedTags = [];
    List<String> checklistItems = [];
    DateTime? reminderTime;
    String? customTypeInput;

    final List<String> eventTypes = [
      settings.strings.translate('task'),
      settings.strings.translate('schedule'),
      settings.strings.translate('workshift'),
      settings.strings.translate('deadline'),
      settings.strings.translate('custom'),
    ];
    final List<String> priorities = ['low', 'medium', 'high'];

    final bool? shouldRefresh = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Xác định xem có hiện các trường dành riêng cho Task không
            bool showTaskFields = [
              settings.strings.translate('task'),
              settings.strings.translate('deadline'),
              settings.strings.translate('custom')
            ].contains(selectedType);

            bool showTagInput =
                selectedType == settings.strings.translate('custom');

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: colorScheme.surface, // Màu nền theo Theme
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh kéo (Handle)
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),

                    // Tiêu đề Sheet
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(settings.strings.translate('add_event'),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface)),
                        Icon(_getIconForType(selectedType),
                            color: colorScheme.primary, size: 28),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 1. Loại sự kiện
                    DropdownButtonFormField<String>(
                      value: eventTypes.contains(selectedType)
                          ? selectedType
                          : settings.strings.translate('task'),
                      dropdownColor: colorScheme.surface,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: _inputDecoration(
                          settings.strings.translate('event_type'),
                          Icons.category,
                          theme),
                      items: eventTypes
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t,
                                  style:
                                      TextStyle(color: colorScheme.onSurface))))
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 12),

                    // Input cho Custom Type
                    if (showTagInput) ...[
                      TextField(
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: _inputDecoration(
                            settings.strings.translate('custom_type_name'),
                            Icons.edit,
                            theme),
                        onChanged: (val) => customTypeInput = val,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 2. Tiêu đề
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: _inputDecoration(
                          settings.strings.translate('title'),
                          Icons.title,
                          theme),
                    ),
                    const SizedBox(height: 12),

                    // 3. Thời gian (Sử dụng _buildTimeBox đã fix overflow)
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
                            child: _buildTimeBox(
                                Icons.calendar_today,
                                DateFormat('dd/MM/yyyy').format(selectedDate),
                                theme),
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
                            child: _buildTimeBox(Icons.access_time,
                                startTime.format(context), theme),
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
                            child: _buildTimeBox(Icons.access_time_filled,
                                endTime.format(context), theme),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 4. Nhắc nhở
                    if (showTaskFields) ...[
                      DropdownButtonFormField<int>(
                        value: reminderTime == null ? 0 : 1,
                        dropdownColor: colorScheme.surface,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: _inputDecoration(
                            settings.strings.translate('reminder'),
                            Icons.notifications,
                            theme,
                            iconColor: Colors.purple),
                        items: [
                          DropdownMenuItem(
                              value: 0,
                              child: Text(
                                  settings.strings.translate('no_reminder'),
                                  style:
                                      TextStyle(color: colorScheme.onSurface))),
                          DropdownMenuItem(
                              value: 15,
                              child: Text(
                                  settings.strings.translate('reminder_15min'),
                                  style:
                                      TextStyle(color: colorScheme.onSurface))),
                          DropdownMenuItem(
                              value: 60,
                              child: Text(
                                  settings.strings.translate('reminder_1hour'),
                                  style:
                                      TextStyle(color: colorScheme.onSurface))),
                          DropdownMenuItem(
                              value: 1,
                              child: Text(
                                  settings.strings
                                      .translate('reminder_custom_time'),
                                  style:
                                      TextStyle(color: colorScheme.onSurface))),
                        ],
                        onChanged: (val) async {
                          if (val == 0) {
                            setModalState(() => reminderTime = null);
                          } else if (val == 1) {
                            final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030));
                            if (pickedDate != null) {
                              final pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now());
                              if (pickedTime != null) {
                                setModalState(() {
                                  reminderTime = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute);
                                });
                              }
                            }
                          } else {
                            final startDt = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                startTime.hour,
                                startTime.minute);
                            setModalState(() => reminderTime =
                                startDt.subtract(Duration(minutes: val!)));
                          }
                        },
                      ),
                      if (reminderTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 12),
                          child: Text(
                            "⏰ ${settings.strings.translate('reminder')}: ${DateFormat('dd/MM HH:mm').format(reminderTime!)}",
                            style: const TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

                    // 5. Priority
                    if (showTaskFields) ...[
                      DropdownButtonFormField<String>(
                        value: selectedPriority,
                        dropdownColor: colorScheme.surface,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: _inputDecoration(
                            settings.strings.translate('priority'),
                            Icons.flag,
                            theme,
                            iconColor: Colors.orange),
                        items: priorities
                            .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.toUpperCase(),
                                    style: TextStyle(
                                        color: colorScheme.onSurface))))
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedPriority = val!),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 6. Custom Tags Input
                    if (showTaskFields) ...[
                      TextField(
                        controller: tagController,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: _inputDecoration(
                                settings.strings.translate('enter_tag'),
                                Icons.label,
                                theme)
                            .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(Icons.add_circle,
                                color: colorScheme.primary),
                            onPressed: () {
                              if (tagController.text.isNotEmpty) {
                                setModalState(() {
                                  selectedTags.add(tagController.text.trim());
                                  tagController.clear();
                                });
                              }
                            },
                          ),
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
                                      label: Text(t,
                                          style: TextStyle(
                                              color: colorScheme.onSurface)),
                                      backgroundColor: colorScheme.secondary
                                          .withOpacity(0.2),
                                      deleteIconColor: colorScheme.onSurface,
                                      onDeleted: () => setModalState(
                                          () => selectedTags.remove(t)),
                                    ))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

                    // 7. Checklist
                    if (showTaskFields) ...[
                      const Divider(),
                      Text(settings.strings.translate('checklist'),
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.grey)),
                      ...checklistItems.asMap().entries.map((entry) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_box_outline_blank,
                                size: 20),
                            title: Text(entry.value,
                                style: TextStyle(color: colorScheme.onSurface)),
                            trailing: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.red, size: 20),
                              onPressed: () => setModalState(
                                  () => checklistItems.removeAt(entry.key)),
                            ),
                          )),
                      TextField(
                        controller: checklistController,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: _inputDecoration(
                                settings.strings
                                    .translate('add_checklist_item'),
                                Icons.playlist_add,
                                theme)
                            .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(Icons.add, color: colorScheme.primary),
                            onPressed: () {
                              if (checklistController.text.isNotEmpty) {
                                setModalState(() {
                                  checklistItems
                                      .add(checklistController.text.trim());
                                  checklistController.clear();
                                });
                              }
                            },
                          ),
                        ),
                        onSubmitted: (val) {
                          if (val.isNotEmpty) {
                            setModalState(() {
                              checklistItems.add(val.trim());
                              checklistController.clear();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 8. Mô tả & Note
                    const Divider(),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: _inputDecoration(
                          settings.strings.translate('description'),
                          Icons.description,
                          theme),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: _inputDecoration(
                          settings.strings.translate('note_hint'),
                          Icons.note_alt,
                          theme,
                          fillColor: colorScheme
                              .surfaceVariant), // Dùng surfaceVariant cho khác biệt
                    ),
                    const SizedBox(height: 20),

                    // Nút Lưu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () async {
                          if (titleController.text.isEmpty) return;

                          // Handle custom type input
                          if (selectedType ==
                                  settings.strings.translate('custom') &&
                              customTypeInput != null &&
                              customTypeInput!.isNotEmpty) {
                            selectedTags.add(customTypeInput!);
                          }

                          await _saveEventToDB(
                            title: titleController.text,
                            desc: descController.text,
                            note: noteController.text,
                            uiType: selectedType,
                            priority: selectedPriority,
                            tags: selectedTags,
                            date: selectedDate,
                            start: startTime,
                            end: endTime,
                            checklist: checklistItems,
                            reminderAt: reminderTime,
                            settings: settings,
                          );
                          if (mounted) Navigator.pop(context, true);
                        },
                        child: Text(settings.strings.translate('save_event'),
                            style: TextStyle(
                                color: colorScheme.onPrimary,
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

  // --- LOGIC LƯU DB: PHIÊN BẢN ĐÃ FIX HOÀN CHỈNH ---
  Future<void> _saveEventToDB({
    required String title,
    required String desc,
    required String note,
    required String uiType,
    required String priority,
    required List<String> tags,
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
    required List<String> checklist,
    required DateTime? reminderAt,
    required SettingsProvider settings,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final startDt =
        DateTime(date.year, date.month, date.day, start.hour, start.minute);
    final endDt =
        DateTime(date.year, date.month, date.day, end.hour, end.minute);

    String dbType = 'task';
    bool shouldCreateTask = false;

    // Map ngôn ngữ về giá trị DB
    if (uiType == settings.strings.translate('schedule'))
      dbType = 'schedule';
    else if (uiType == settings.strings.translate('workshift'))
      dbType = 'workshift';
    else if (uiType == settings.strings.translate('deadline')) {
      dbType = 'deadline';
      shouldCreateTask = true;
    } else {
      dbType = 'task';
      shouldCreateTask = true;
    } // Task, Custom -> task

    try {
      // 1. Tạo Event
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
          .select('id')
          .single();
      final eventId = resEvent['id'];

      // 2. Tạo Note
      if (note.isNotEmpty) {
        await _supabase
            .from('notes')
            .insert({'user_id': user.id, 'content': note, 'event_id': eventId});
      }

      // 3. Tạo Task (VÀ CÁC THÀNH PHẦN CON)
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
            .select('id')
            .single();
        final taskId = resTask['id'];

        // Reminder: Chỉ lưu khi đã có taskId (Tránh lỗi null constraint)
        if (reminderAt != null && taskId != null) {
          await _supabase.from('reminders').insert({
            'user_id': user.id,
            'event_id': eventId,
            'task_id': taskId,
            'remind_time': reminderAt.toIso8601String(),
            'status': 'pending',
          });
        }

        // Tags: Bọc try-catch để tránh crash nếu chưa config RLS
        if (tags.isNotEmpty) {
          try {
            for (String tagName in tags) {
              var tagRes = await _supabase
                  .from('tags')
                  .select('id')
                  .eq('name', tagName)
                  .eq('user_id', user.id)
                  .maybeSingle();
              dynamic tagId = tagRes != null
                  ? tagRes['id']
                  : (await _supabase
                      .from('tags')
                      .insert({'user_id': user.id, 'name': tagName})
                      .select('id')
                      .single())['id'];
              await _supabase
                  .from('task_tags')
                  .insert({'task_id': taskId, 'tag_id': tagId});
            }
          } catch (e) {
            debugPrint("Tag save error (RLS?): $e");
          }
        }

        // Checklist: Bọc try-catch
        if (checklist.isNotEmpty) {
          try {
            final checklistData = checklist
                .map((item) =>
                    {'task_id': taskId, 'item_text': item, 'is_done': false})
                .toList();
            await _supabase.from('checklist_items').insert(checklistData);
          } catch (e) {
            debugPrint("Checklist save error (RLS?): $e");
          }
        }
      }
    } catch (e) {
      debugPrint('DB Error: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // --- HELPER WIDGETS (THEME SUPPORT) ---

  InputDecoration _inputDecoration(String label, IconData icon, ThemeData theme,
      {Color? iconColor, Color? fillColor, Color? labelColor}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: labelColor ?? theme.hintColor),
      prefixIcon:
          Icon(icon, color: iconColor ?? theme.iconTheme.color ?? Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor:
          fillColor ?? theme.inputDecorationTheme.fillColor ?? Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // WIDGET FIX OVERFLOW: Dùng Flexible
  Widget _buildTimeBox(IconData icon, String text, ThemeData theme,
      {Color? textColor, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: borderColor ?? theme.dividerColor),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: theme.iconTheme.color ?? Colors.grey),
          const SizedBox(width: 4),
          // QUAN TRỌNG: Flexible giúp text co lại nếu không đủ chỗ
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor ?? theme.textTheme.bodyLarge?.color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    // Map icon đơn giản, có thể mở rộng
    return Icons.event;
  }

  // --- TEMPLATES & HEADER ---
  void _showTemplatesSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(25))),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chọn mẫu nhanh',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
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
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: EventColors.accentBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: EventColors.primaryBlue)),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
      subtitle:
          Text(desc, style: TextStyle(color: theme.textTheme.bodySmall?.color)),
      onTap: () {
        Navigator.pop(context);
        _showAddEventSheet(context,
            preTitle: title, preType: type, preDesc: desc);
      },
    );
  }

  // --- GIAO DIỆN CHÍNH ---
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(settings, colorScheme),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          _buildMonthNavigator(settings, colorScheme),
                          const SizedBox(height: 10),
                          _buildViewSwitcher(theme),
                          const SizedBox(height: 16),
                          _buildCalendarGrid(settings, theme),
                          const SizedBox(height: 20),
                          _buildLegendChips(colorScheme),
                          const SizedBox(height: 16),
                          _buildModeToggle(),
                          const SizedBox(height: 24),
                          _buildScheduleListFromData(settings, theme),
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

  // Widget Header
  Widget _buildHeader(SettingsProvider settings, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: EventColors.primaryBlue, size: 28),
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
                              color: colors.onSurface),
                          overflow: TextOverflow.ellipsis),
                      Text(settings.strings.translate('schedules'),
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withOpacity(0.6)),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionBtn(
                  Icons.access_time, settings.strings.translate('templates'),
                  isOutlined: true,
                  textColor: colors.onSurface.withOpacity(0.6),
                  onTap: () => _showTemplatesSheet(context)),
              const SizedBox(width: 6),
              _buildActionBtn(Icons.add, 'Add',
                  isOutlined: false, textColor: Colors.white, onTap: () async {
                await _showAddEventSheet(context);
              }),
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
          color: isOutlined ? Colors.transparent : EventColors.accentBlue,
          borderRadius: BorderRadius.circular(20),
          border:
              isOutlined ? Border.all(color: textColor.withOpacity(0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            // Chỉ hiện text nếu ngắn để tránh overflow
            if (label.length < 10) ...[
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(SettingsProvider settings, ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            onPressed: () => setState(() => _focusedDay =
                DateTime(_focusedDay.year, _focusedDay.month - 1)),
            icon: Icon(Icons.chevron_left,
                color: colors.onSurface.withOpacity(0.6))),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy', settings.localeCode).format(_focusedDay),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
            onPressed: () => setState(() => _focusedDay =
                DateTime(_focusedDay.year, _focusedDay.month + 1)),
            icon: Icon(Icons.chevron_right,
                color: colors.onSurface.withOpacity(0.6))),
      ],
    );
  }

  Widget _buildViewSwitcher(ThemeData theme) {
    final subColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: theme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildSwitchTab('Calendar', Icons.calendar_view_month,
              _calendarFormat == CalendarFormat.month, subColor, () {
            setState(() => _calendarFormat = CalendarFormat.month);
          }),
          _buildSwitchTab('Week', Icons.access_time,
              _calendarFormat == CalendarFormat.week, subColor, () {
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
            color: isActive ? EventColors.primaryBlue : Colors.transparent,
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

  Widget _buildCalendarGrid(SettingsProvider settings, ThemeData theme) {
    final colors = theme.colorScheme;
    final subColor = theme.textTheme.bodySmall?.color ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
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
              _buildDayCard(day, theme.cardColor, colors.onSurface),
          selectedBuilder: (context, day, focusedDay) => _buildDayCard(
              day, theme.cardColor, colors.onSurface,
              isSelected: true),
          todayBuilder: (context, day, focusedDay) => _buildDayCard(
              day, theme.cardColor, colors.onSurface,
              isToday: true),
          markerBuilder: (context, day, events) {
            final normalizedDay = DateTime(day.year, day.month, day.day);
            final dayEvents = _eventsByDay[normalizedDay];
            if (dayEvents == null || dayEvents.isEmpty) return null;
            List<Color> markers = [];
            for (var e in dayEvents) {
              if (e['isTask'] == true)
                markers.add(EventColors.task);
              else {
                final type = e['type'].toString().toLowerCase();
                if (type == 'work' || type == 'workshift')
                  markers.add(EventColors.work);
                else if (type == 'class')
                  markers.add(EventColors.classColor);
                else if (type == 'schedule')
                  markers.add(EventColors.scheduleBlue);
                else
                  markers.add(EventColors.deadline);
              }
              if (markers.length >= 3) break;
            }
            return _buildDots(markers);
          },
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
              color: subColor, fontWeight: FontWeight.bold, fontSize: 12),
          weekendStyle: TextStyle(
              color: subColor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDayCard(DateTime day, Color cardColor, Color textColor,
      {bool isSelected = false, bool isToday = false}) {
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color:
            isSelected ? EventColors.scheduleBlue.withOpacity(0.1) : cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isToday
                ? EventColors.scheduleBlue
                : (isSelected
                    ? Colors.transparent
                    : Colors.grey.shade100.withOpacity(0.1))),
      ),
      child: Center(
          child: Text('${day.day}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isToday ? EventColors.scheduleBlue : textColor,
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

  Widget _buildLegendChips(ColorScheme colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip('Work', EventColors.work),
          _buildChip('Class', EventColors.classColor),
          _buildChip('Deadline', EventColors.deadline),
          _buildChip('Task', EventColors.task),
          _buildChip('Today', EventColors.todayChip, textColor: Colors.black87),
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
        _buildModeBtn('Schedule', EventColors.scheduleBlue, true),
        const SizedBox(width: 8),
        _buildModeBtn('Note', EventColors.primaryBlue.withOpacity(0.5), false),
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

  Widget _buildScheduleListFromData(
      SettingsProvider settings, ThemeData theme) {
    final colors = theme.colorScheme;
    final subColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
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
            color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
        child: Center(
            child: Text(settings.strings.translate('no_upcoming_events'),
                style: TextStyle(color: subColor))),
      );
    }

    return Container(
      decoration: BoxDecoration(
          color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
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
                  Color color = EventColors.task;
                  if (e['isTask'] == false) {
                    final type = e['type'].toString().toLowerCase();
                    if (type == 'work' || type == 'workshift')
                      color = EventColors.work;
                    else if (type == 'class')
                      color = EventColors.classColor;
                    else if (type == 'schedule')
                      color = EventColors.scheduleBlue;
                    else
                      color = EventColors.deadline;
                  }
                  return _buildEvent(e, color, colors.onSurface);
                }).toList(),
                colors.onSurface,
                subColor),
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

  Widget _buildEvent(Map<String, dynamic> event, Color color, Color textColor) {
    return InkWell(
      onTap: () async {
        try {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(
                  data: event, isTask: event['isTask'] ?? false),
            ),
          );
          if (result == true) _fetchDatabaseData();
        } catch (e) {
          debugPrint("Error navigating: $e");
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              // FIX OVERFLOW
              child: Text(
                event['title'] ?? 'Untitled',
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: textColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 16, color: Colors.grey.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
