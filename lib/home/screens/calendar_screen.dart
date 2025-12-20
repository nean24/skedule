import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// Bảng màu dành riêng cho màn hình Lịch để đồng bộ với thiết kế
const Color kPrimaryBlue = Color(0xFF3B5998);
const Color kSelectedBlue = Color(0xFF3D5A98);
const Color kCalendarScaffoldBg = Color(0xFFEEF0F7);
const Color kCardBackground = Colors.white;
const Color kPrimaryTextColor = Color(0xFF333333);
const Color kSecondaryTextColor = Color(0xFF666666);
const Color kLightGray = Color(0xFFE0E0E0);

// Widget chính cho màn hình Lịch
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime(2025, 10, 21);
  DateTime? _selectedDay = DateTime(2025, 10, 21);
  @override
  Widget build(BuildContext context) {
    // Sửa lỗi: Thay thế SingleChildScrollView + Column bằng ListView
    return Scaffold(
      backgroundColor: kCalendarScaffoldBg, // Giữ màu nền
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0), // Đặt padding cho ListView
          children: [
            // Đưa các widget con trực tiếp vào ListView
            _buildHeader(),
            const SizedBox(height: 20),
            _buildActionButtons(context),
            const SizedBox(height: 20),
            _buildCalendar(),
            const SizedBox(height: 20),
            _buildWeekSchedule(),
          ],
        ),
      ),
    );
  }
  // Header với tên màn hình và icon
  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(Icons.calendar_month_rounded, color: kPrimaryBlue, size: 36),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calendar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
            Text('Schedule & deadlines', style: TextStyle(color: kSecondaryTextColor)),
          ],
        )
      ],
    );
  }

  // Các nút "Templates" và "Add Event"
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            _showTemplatesDialog(context);
          },
          icon: const Icon(Icons.watch_later_outlined, size: 18),
          label: const Text('Templates'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kLightGray,
            foregroundColor: kPrimaryTextColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            _showAddEventDialog(context);
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Event'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  // Widget Lịch
  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        headerStyle: HeaderStyle(
          titleTextFormatter: (date, locale) => DateFormat.yMMMM(locale).format(date),
          titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          formatButtonVisible: false,
          leftChevronIcon: const Icon(Icons.chevron_left, color: kSecondaryTextColor),
          rightChevronIcon: const Icon(Icons.chevron_right, color: kSecondaryTextColor),
        ),
        calendarStyle: CalendarStyle(
          // === SỬA LỖI: Thêm các dòng này để đồng bộ shape ===
          defaultDecoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(8),
          ),
          weekendDecoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(8),
          ),
          outsideDecoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(8),
          ),
          // ===============================================

          todayDecoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.3),
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(8)
          ),
          selectedDecoration: BoxDecoration(
            color: kSelectedBlue,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(8),
          ),
          defaultTextStyle: const TextStyle(fontWeight: FontWeight.w500),
          weekendTextStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
            weekendStyle: TextStyle(color: kSecondaryTextColor),
            weekdayStyle: TextStyle(color: kSecondaryTextColor)
        ),
      ),
    );
  }

  // === THAY ĐỔI BẮT ĐẦU TỪ ĐÂY ===

  // Widget Lịch trình trong tuần (Week Schedule)
  Widget _buildWeekSchedule() {
    // 1. Lấy ngày hôm qua, hôm nay (đang chọn), và ngày mai
    // Dùng _selectedDay, nếu null thì dùng tạm DateTime.now()
    final DateTime currentDay = _selectedDay ?? DateTime.now();
    final DateTime prevDay = currentDay.subtract(const Duration(days: 1));
    final DateTime nextDay = currentDay.add(const Duration(days: 1));

    // 2. Định dạng cho tiêu đề (ví dụ: "Tue 21")
    final DateFormat headerFormat = DateFormat('E d');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.watch_later_outlined, color: kSecondaryTextColor),
                  SizedBox(width: 8),
                  Text('Week Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Hide', style: TextStyle(color: kSecondaryTextColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bảng lịch trình tĩnh để minh họa
          Table(
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey.shade300, width: 1),
              verticalInside: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              // === PHẦN SỬA 1: Header (Làm động) ===
              TableRow(children: [
                const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold, color: kSecondaryTextColor)))
                ),
                _buildHeaderCell(headerFormat.format(prevDay)),
                _buildHeaderCell(headerFormat.format(currentDay), isSelected: true),
                _buildHeaderCell(headerFormat.format(nextDay)),
              ]),

              // === PHẦN SỬA 2: Tạo 24 hàng (0h - 23h) ===
              ...List.generate(24, (index) {
                final hour = index; // 0, 1, 2, ..., 23

                // Định dạng thời gian 12h (AM/PM)
                final displayHour = (hour == 0 || hour == 12) ? 12 : (hour > 12 ? hour - 12 : hour);
                final ampm = hour >= 12 ? 'PM' : 'AM';
                final timeString = '$displayHour:00 $ampm';

                return TableRow(children: [
                  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(child: Text(timeString, style: const TextStyle(fontSize: 12, color: kSecondaryTextColor)))
                  ),
                  // Các ô trống cho lịch trình
                  const Padding(padding: EdgeInsets.all(8.0), child: Text('')),
                  const Padding(padding: EdgeInsets.all(8.0), child: Text('')),
                  const Padding(padding: EdgeInsets.all(8.0), child: Text('')),
                ]);
              })
            ],
          )
        ],
      ),
    );
  }

  // Widget phụ trợ cho tiêu đề của bảng lịch trình
  Widget _buildHeaderCell(String text, {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? kPrimaryBlue : kPrimaryTextColor,
          ),
        ),
      ),
    );
  }
}
// === THAY ĐỔI KẾT THÚC TẠI ĐÂY ===


// Hàm hiển thị Dialog "Add Event"
void _showAddEventDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Event Type'),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: kCalendarScaffoldBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: 'Note',
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: ['Note', 'Task', 'Meeting'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Icon(value == 'Note' ? Icons.note_alt_outlined : Icons.task_alt, size: 18),
                            const SizedBox(width: 8),
                            Text(value),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: 15),
                const Text('Title'),
                const SizedBox(height: 5),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter event title',
                    filled: true,
                    fillColor: kCalendarScaffoldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text('Description'),
                const SizedBox(height: 5),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter event description',
                    filled: true,
                    fillColor: kCalendarScaffoldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: kSecondaryTextColor)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                      child: const Text('Save Event'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      );
    },
  );
}

// Hàm hiển thị Dialog "Templates"
void _showTemplatesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sửa lỗi Overflow: Bọc tiêu đề bằng Flexible
                    const Flexible(
                      child: Text(
                        'Apply Timetable Template',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Thêm đề phòng
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose a timetable template to quickly add recurring events to your calendar.',
                  style: TextStyle(color: kSecondaryTextColor, fontSize: 14),
                ),
                const SizedBox(height: 20),
                _buildTemplateCard(
                  context,
                  icon: Icons.work_outline,
                  title: 'Weekly Work Schedule',
                  eventCount: 2,
                  events: ['Morning Shift - 8:00 AM', 'Evening Shift - 4:00 PM'],
                ),
                const SizedBox(height: 15),
                _buildTemplateCard(
                  context,
                  icon: Icons.school_outlined,
                  title: 'Fall Semester Schedule',
                  eventCount: 3,
                  events: ['Maths 101 - 9:00 AM', 'Physics 201 - 11:00 AM', '+1 more events'],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(color: kSecondaryTextColor)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// Widget cho một thẻ Template
Widget _buildTemplateCard(BuildContext context, {required IconData icon, required String title, required int eventCount, required List<String> events}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
          )
        ]
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start, // Thêm để căn chỉnh
          children: [
            // Sửa lỗi Overflow: Bọc Row con bằng Flexible
            Flexible(
              child: Row(
                children: [
                  Icon(icon, color: kPrimaryTextColor),
                  const SizedBox(width: 8),
                  // Bọc Text bằng Flexible để tự xuống hàng
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8), // Thêm khoảng đệm
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kLightGray.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$eventCount events', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            )
          ],
        ),
        const SizedBox(height: 10),
        ...events.map((event) => Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(event, style: const TextStyle(color: kSecondaryTextColor)),
        )),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Apply Template'),
          ),
        )
      ],
    ),
  );
}

