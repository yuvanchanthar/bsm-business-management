import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/labour_model.dart';
import '../models/attendance_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late ApiService _apiService;
  List<LabourModel> _labours = [];

  // Map from labourId → 'full_day' | 'half_day' | 'absent' | null
  final Map<String, String?> _statusMap = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  DateTime _selectedDate = DateTime.now();

  /// The month currently shown in the calendar (day is always 1)
  late DateTime _calendarMonth;

  /// Set of "YYYY-MM-DD" strings that have attendance records
  Set<String> _attendedDates = {};

  // ── Status constants ──────────────────────────────────────────────────────

  static const String kFullDay = 'full_day';
  static const String kHalfDay = 'half_day';
  static const String kAbsent = 'absent';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _calendarMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _initService();
  }

  Future<void> _initService() async {
    final tokenService = await TokenService.getInstance();
    _apiService = ApiService(tokenService);
    _fetchData();
    _fetchAttendedDates();
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchAttendedDates() async {
    try {
      final dates = await _apiService.getAttendedDateStrings();
      debugPrint('[Calendar] Attended dates received in widget: ${dates.length}');
      for (final d in dates) {
        debugPrint('[Calendar]   Attended: $d');
      }
      if (mounted) setState(() => _attendedDates = dates);
      debugPrint('[Calendar] _attendedDates set in state. Length: ${_attendedDates.length}');
    } catch (e) {
      // Non-critical – calendar shading is a visual enhancement
      debugPrint('[Calendar] Could not load attended dates: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getLabours(),
        _apiService.getAttendanceRecords(_selectedDate),
      ]);

      final labours = results[0] as List<LabourModel>;
      final attendanceRecords = results[1] as List<AttendanceEntry>;

      if (mounted) {
        setState(() {
          _labours = labours;
          _statusMap.clear();

          for (final l in labours) {
            final existing =
                attendanceRecords.where((r) => r.labourId == l.id).firstOrNull;
            if (existing != null) {
              _statusMap[l.id!] = existing.status;
            } else {
              _statusMap[l.id!] = null;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load data: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Summary getters ───────────────────────────────────────────────────────

  int get _fullDayCount => _statusMap.values.where((s) => s == kFullDay).length;
  int get _halfDayCount => _statusMap.values.where((s) => s == kHalfDay).length;
  int get _absentCount => _statusMap.values.where((s) => s == kAbsent).length;

  /// Full Day = 1 day, Half Day = 0.5 day, Absent = 0.
  double get _daysWorked => _fullDayCount + (_halfDayCount * 0.5);

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submitAttendance() async {
    if (_labours.isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      final entries = _labours
          .where((l) => _statusMap[l.id!] != null)
          .map((l) {
        return AttendanceEntry(
          labourId: l.id!,
          name: l.name,
          status: _statusMap[l.id!]!,
          wage: l.dailyWage,
        );
      }).toList();

      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please mark at least one labour')),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      await _apiService.submitAttendance(_selectedDate, entries);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Attendance saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh both the daily data AND the attended-dates set so the calendar
      // immediately reflects the new shading.
      await Future.wait([_fetchData(), _fetchAttendedDates()]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Calendar helpers ──────────────────────────────────────────────────────

  String _toDateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _hasAttendance(DateTime d) {
    final key = _toDateKey(d);
    final result = _attendedDates.contains(key);
    // Only print for the current calendar month to avoid log spam
    if (d.month == _calendarMonth.month) {
      debugPrint('[Calendar] _hasAttendance($key) → $result  (set size: ${_attendedDates.length})');
    }
    return result;
  }

  bool _isSelected(DateTime d) =>
      d.year == _selectedDate.year &&
      d.month == _selectedDate.month &&
      d.day == _selectedDate.day;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _selectDay(DateTime d) {
    if (d.isAfter(DateTime.now())) return; // disallow future dates
    setState(() => _selectedDate = d);
    _fetchData();
  }

  void _prevMonth() {
    setState(() {
      _calendarMonth =
          DateTime(_calendarMonth.year, _calendarMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 1);
    if (next.isAfter(DateTime(now.year, now.month + 1, 1))) return;
    setState(() => _calendarMonth = next);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Daily Attendance',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
            onPressed: () {
              _fetchData();
              _fetchAttendedDates();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                // ── Calendar + Stats ────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Inline calendar
                      _buildCalendar(),

                      const SizedBox(height: 16),

                      // ── Stats row (4 cards) ─────────────────────────────
                      Row(
                        children: [
                          _buildStat(
                              'FULL DAYS', '$_fullDayCount', Colors.green),
                          const SizedBox(width: 8),
                          _buildStat(
                              'HALF DAYS', '$_halfDayCount', Colors.orange),
                          const SizedBox(width: 8),
                          _buildStat('ABSENT', '$_absentCount', Colors.red),
                          const SizedBox(width: 8),
                          _buildStat(
                              'WORKED',
                              _daysWorked % 1 == 0
                                  ? '${_daysWorked.toInt()}'
                                  : _daysWorked.toStringAsFixed(1),
                              AppColors.primaryGreen),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Labour list ─────────────────────────────────────────
                Expanded(
                  child: _labours.isEmpty
                      ? Center(
                          child: Text(
                            'No labours to mark attendance for.',
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 4),
                          itemCount: _labours.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final labour = _labours[index];
                            final status = _statusMap[labour.id!];
                            return _buildAttendanceRow(labour, status);
                          },
                        ),
                ),

                // ── Submit button ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitAttendance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 20),
                      label: Text(
                        _isSubmitting ? 'Saving...' : 'Save Attendance',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Custom inline calendar ────────────────────────────────────────────────

  Widget _buildCalendar() {
    const weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Build month grid
    final firstDay = _calendarMonth;
    final daysInMonth =
        DateUtils.getDaysInMonth(firstDay.year, firstDay.month);

    // weekday 1=Mon ... 7=Sun  →  offset so Monday = column 0
    final startWeekday = firstDay.weekday; // 1-7
    final leadingEmpty = startWeekday - 1; // blanks before day 1

    final cells = <DateTime?>[];
    for (int i = 0; i < leadingEmpty; i++) cells.add(null);
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(firstDay.year, firstDay.month, d));
    }
    // Pad to full rows
    while (cells.length % 7 != 0) cells.add(null);

    final monthName = _monthLabel(firstDay.month);
    final now = DateTime.now();
    final isCurrentOrFutureMonth =
        DateTime(firstDay.year, firstDay.month + 1, 1)
            .isAfter(DateTime(now.year, now.month + 1, 1));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Month header ──────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: AppColors.textPrimary),
                  onPressed: _prevMonth,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Text(
                  '$monthName ${firstDay.year}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      color: isCurrentOrFutureMonth
                          ? Colors.grey.shade300
                          : AppColors.textPrimary),
                  onPressed: isCurrentOrFutureMonth ? null : _nextMonth,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // ── Weekday header row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: weekDays
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 4),

          // ── Day cells grid ────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (int row = 0;
                    row < cells.length ~/ 7;
                    row++) ...[
                  Row(
                    children: List.generate(7, (col) {
                      final date = cells[row * 7 + col];
                      return Expanded(child: _buildDayCell(date));
                    }),
                  ),
                ],
              ],
            ),
          ),

          // ── Legend ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Attendance recorded',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Selected',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime? date) {
    if (date == null) {
      return const SizedBox(height: 38);
    }

    final selected = _isSelected(date);
    final attended = _hasAttendance(date);
    final today = _isToday(date);
    final isFuture = date.isAfter(DateTime.now());

    Color? bgColor;
    Color textColor = AppColors.textPrimary;
    FontWeight fontWeight = FontWeight.w500;
    BoxBorder? border;

    if (selected) {
      bgColor = AppColors.primaryGreen;
      textColor = Colors.white;
      fontWeight = FontWeight.bold;
    } else if (attended) {
      bgColor = AppColors.primaryGreen.withValues(alpha: 0.18);
      textColor = AppColors.primaryGreen;
      fontWeight = FontWeight.w600;
    } else if (today) {
      border = Border.all(color: AppColors.primaryGreen, width: 1.5);
    }

    if (isFuture) {
      textColor = Colors.grey.shade400;
      bgColor = null;
      border = null;
    }

    return GestureDetector(
      onTap: isFuture ? null : () => _selectDay(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        height: 34,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: fontWeight,
            color: textColor,
          ),
        ),
      ),
    );
  }

  String _monthLabel(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }

  // ── Labour attendance card ───────────────────────────────────────────────

  Widget _buildAttendanceRow(LabourModel labour, String? status) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + name/role
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  labour.name.isNotEmpty ? labour.name[0].toUpperCase() : 'L',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labour.name,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      '${labour.role} · ₹${labour.dailyWage.toStringAsFixed(0)}/day',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Three-chip selector ─────────────────────────────────────
          Row(
            children: [
              _buildChip(
                label: 'Full Day',
                status: kFullDay,
                selectedStatus: status,
                selectedColor: Colors.green,
                labourId: labour.id!,
              ),
              const SizedBox(width: 8),
              _buildChip(
                label: 'Half Day',
                status: kHalfDay,
                selectedStatus: status,
                selectedColor: Colors.orange,
                labourId: labour.id!,
              ),
              const SizedBox(width: 8),
              _buildChip(
                label: 'Absent',
                status: kAbsent,
                selectedStatus: status,
                selectedColor: Colors.red,
                labourId: labour.id!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Selectable chip ──────────────────────────────────────────────────────

  Widget _buildChip({
    required String label,
    required String status,
    required String? selectedStatus,
    required Color selectedColor,
    required String labourId,
  }) {
    final isSelected = selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusMap[labourId] = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? selectedColor : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Stat card ─────────────────────────────────────────────────────────────

  Widget _buildStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
