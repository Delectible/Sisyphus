/// Short time formats used across the app.
String clock(Duration d) {
  final s = d.inSeconds < 0 ? 0 : (d.inMilliseconds / 1000).ceil();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

/// "1h 40m", "25m", "40s".
String span(Duration d) {
  final m = d.inMinutes;
  if (m == 0) return d.inSeconds <= 0 ? '0m' : '${d.inSeconds}s';
  final h = m ~/ 60, r = m % 60;
  if (h == 0) return '${r}m';
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

/// Hours with one decimal: "18.5".
String hours(Duration d) {
  final h = d.inMinutes / 60;
  return h >= 100 ? h.round().toString() : h.toStringAsFixed(1);
}

String timeOfDay(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String date(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';
