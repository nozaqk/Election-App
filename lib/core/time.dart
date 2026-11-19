import 'package:intl/intl.dart';

/// Formats a remaining duration as `"{d}d HH:MM:SS"`.
String formatCountdown(Duration d) {
  if (d.inSeconds <= 0) return '0d 00:00:00';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.inDays}d ${two(d.inHours % 24)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// Formats [dt] in Africa/Accra wall time.
///
/// Accra is UTC+0 year-round with no daylight saving, so the UTC clock
/// reading is exactly the local wall time — no timezone database needed.
String formatAccra(DateTime dt) =>
    DateFormat('dd MMM yyyy, HH:mm').format(dt.toUtc());

/// Short time-of-day in Accra, e.g. `14:05`.
String formatAccraTime(DateTime dt) =>
    DateFormat('HH:mm').format(dt.toUtc());

/// Greeting for the home screen based on the Accra hour.
String greetingFor(DateTime now) {
  final hour = now.toUtc().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
