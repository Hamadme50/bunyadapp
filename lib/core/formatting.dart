import 'package:intl/intl.dart';

/// Money, dates and the small phrases the screens repeat — the Dart twin of the
/// web app's `format.js`, so both clients word things identically.

final NumberFormat _grouped = NumberFormat('#,##0', 'en_US');
final NumberFormat _grouped2 = NumberFormat('#,##0.00', 'en_US');

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _days = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

/// "Rs 16,665,200" — the currency label comes from the project, never a locale.
String money(num? amount, [String currency = 'Rs']) {
  final value = (amount ?? 0).toDouble();
  if (!value.isFinite) return '$currency 0';
  final rounded = (value * 100).round() / 100;
  final text = rounded == rounded.truncateToDouble()
      ? _grouped.format(rounded)
      : _grouped2.format(rounded);
  return '$currency $text';
}

String number(num? value) {
  final parsed = (value ?? 0).toDouble();
  if (!parsed.isFinite) return '0';
  return parsed == parsed.truncateToDouble()
      ? _grouped.format(parsed)
      : _grouped2.format(parsed);
}

/// Parses the API's ISO date without letting a timezone shift the day.
DateTime? parseDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final parts = iso.substring(0, iso.length < 10 ? iso.length : 10).split('-');
  if (parts.length < 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null || m < 1 || m > 12) return null;
  return DateTime(y, m, d);
}

/// "12 Jul 2026"
String? longDate(String? iso) {
  final date = parseDate(iso);
  if (date == null) return null;
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String? longDateOf(DateTime? date) {
  if (date == null) return null;
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

/// The timeline's stacked day-over-month pair.
({String day, String month}) dayParts(String? iso) {
  final date = parseDate(iso);
  if (date == null) return (day: '--', month: '');
  return (
    day: date.day.toString().padLeft(2, '0'),
    month: '${_months[date.month - 1]} ${date.year}',
  );
}

/// Today as the API wants it: yyyy-MM-dd.
String todayIso() => isoDate(DateTime.now());

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// "2 hours ago", "yesterday", "3 days ago".
String? relative(DateTime? instant) {
  if (instant == null) return null;
  final seconds = DateTime.now().difference(instant.toLocal()).inSeconds;

  if (seconds < 60) return 'just now';
  if (seconds < 3600) {
    final minutes = (seconds / 60).round();
    return '$minutes minute${minutes == 1 ? '' : 's'} ago';
  }
  if (seconds < 86400) {
    final hours = (seconds / 3600).round();
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  }
  final days = (seconds / 86400).round();
  if (days == 1) return 'yesterday';
  if (days < 30) return '$days days ago';
  final months = (days / 30).round();
  if (months < 12) return '$months month${months == 1 ? '' : 's'} ago';
  return longDateOf(instant.toLocal());
}

/// The greeting at the top of the dashboard.
String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Tuesday, 11 Aug 2026"
String todayLong() {
  final now = DateTime.now();
  return '${_days[now.weekday % 7]}, ${now.day} ${_months[now.month - 1]} ${now.year}';
}

/// "3 sites", "1 expense" — count and noun, agreeing.
String plural(num count, String singular, [String? pluralForm]) {
  final word = count == 1 ? singular : (pluralForm ?? '${singular}s');
  return '${number(count)} $word';
}

/// The dates line under a stage name.
String stageDates({String? startedOn, String? completedOn, String? plannedNote}) {
  final started = longDate(startedOn);
  final completed = longDate(completedOn);
  if (started != null && completed != null) return '$started → $completed';
  if (started != null) return 'Started $started';
  if (plannedNote != null && plannedNote.isNotEmpty) return plannedNote;
  return 'Not scheduled yet';
}

/// Reads a decimal the way a person types it — "1,250" and " 84 " both work.
/// Returns null for blank so optional numbers stay optional, and [double.nan]
/// for something that is not a number at all.
double? parseDecimal(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(RegExp(r'[\s,]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned) ?? double.nan;
}

/// Drops a trailing ".0" so 5.0 reads as "5" in a form field.
String plainNumber(num? value) {
  if (value == null) return '';
  if (value is int) return value.toString();
  final d = value.toDouble();
  if (d == d.truncateToDouble()) return d.toInt().toString();
  return d.toString();
}

/// The first word of a name — "Added by Bilal".
String firstName(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return 'someone';
  return trimmed.split(' ').first;
}
