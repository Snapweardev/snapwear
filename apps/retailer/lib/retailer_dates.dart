class ReportDateWindow {
  final DateTime start, end;
  const ReportDateWindow(this.start, this.end);
}

ReportDateWindow reportDateWindow(
  String preset,
  DateTime now, {
  List<DateTime> records = const [],
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final today = DateTime(now.year, now.month, now.day);
  var start = DateTime(today.year, today.month, today.day - 6);
  var end = DateTime(today.year, today.month, today.day + 1);
  if (preset == 'Today') {
    start = today;
  }
  if (preset == 'This month') {
    start = DateTime(today.year, today.month);
  }
  if (preset == 'Last month') {
    start = DateTime(today.year, today.month - 1);
    end = DateTime(today.year, today.month);
  }
  if (preset == 'Last 90 days') {
    start = DateTime(today.year, today.month, today.day - 89);
  }
  if (preset == 'All time') {
    final dates = records.where((d) => !d.isAfter(now)).toList()..sort();
    if (dates.isNotEmpty) {
      start = DateTime(dates.first.year, dates.first.month, dates.first.day);
    }
  }
  if (preset == 'Custom' && customStart != null && customEnd != null) {
    start = DateTime(customStart.year, customStart.month, customStart.day);
    end = DateTime(customEnd.year, customEnd.month, customEnd.day + 1);
    if (!end.isAfter(start)) {
      throw ArgumentError('End date must not precede start date');
    }
  }
  return ReportDateWindow(start, end);
}
