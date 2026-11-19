import 'dart:math';

/// Round to 2 decimals so money never drifts.
double r2(double v) => (v * 100).round() / 100;

String _group(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    b.write(digits[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) b.write(',');
  }
  return b.toString();
}

/// ₱1,250.00
String peso(double v, {bool decimals = true}) {
  final neg = v < 0;
  final fixed = v.abs().toStringAsFixed(decimals ? 2 : 0);
  final parts = fixed.split('.');
  final whole = _group(parts[0]);
  final out = parts.length > 1 ? '$whole.${parts[1]}' : whole;
  return '${neg ? '-' : ''}₱$out';
}

/// Short form for charts / tight tiles: ₱1.2K, ₱3.4M
String pesoShort(double v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  // 999,500 and up would round to "1000K"; show it as millions instead.
  if (a >= 999500) return '$sign₱${(a / 1000000).toStringAsFixed(1)}M';
  if (a >= 10000) return '$sign₱${(a / 1000).toStringAsFixed(0)}K';
  if (a >= 1000) return '$sign₱${(a / 1000).toStringAsFixed(1)}K';
  return '$sign₱${a.toStringAsFixed(0)}';
}

String intFmt(int v) => (v < 0 ? '-' : '') + _group(v.abs().toString());

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String monthName(int m) => _months[m - 1];

/// Nov 9, 2026
String dateFmt(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String timeFmt(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String dateTimeFmt(DateTime d) => '${dateFmt(d)} · ${timeFmt(d)}';

/// Nov 11 · 11:00 AM (the year only when it is not this year), for tight rows.
String dateTimeShort(DateTime d) {
  final year = d.year == DateTime.now().year ? '' : ', ${d.year}';
  return '${_months[d.month - 1]} ${d.day}$year · ${timeFmt(d)}';
}

/// A number for an edit box: 1250 stays "1250", 12.5 becomes "12.50".
String plainAmount(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

String relativeDay(DateTime d) {
  final today = dayStart(DateTime.now());
  final then = dayStart(d);
  final diff = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(then.year, then.month, then.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return dateFmt(d);
}

final _rand = Random();

/// Unique-enough local id (time + random). Safe to reuse as a server id later.
String newId([String prefix = '']) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = _rand.nextInt(1 << 20).toRadixString(36);
  return '$prefix$t$r';
}

/// Normalizes a Philippine mobile number to +639XXXXXXXXX. Returns null if invalid.
String? normalizePhone(String input) {
  var s = input.replaceAll(RegExp(r'[\s\-()]'), '');
  if (s.startsWith('+63')) {
    s = s.substring(3);
  } else if (s.startsWith('63')) {
    s = s.substring(2);
  } else if (s.startsWith('0')) {
    s = s.substring(1);
  }
  if (!RegExp(r'^9\d{9}$').hasMatch(s)) return null;
  return '+63$s';
}

/// Does a saved number (+639171234567) match what the seller typed
/// ("0917 123", "+63 917", "9171234")? Compares digits only.
bool phoneMatches(String stored, String typed) {
  var q = typed.replaceAll(RegExp(r'\D'), '');
  if (q.length < 3) return false; // too short to mean a phone number
  if (q.startsWith('63')) {
    q = q.substring(2);
  } else if (q.startsWith('0')) {
    q = q.substring(1);
  }
  return q.isNotEmpty && stored.replaceAll(RegExp(r'\D'), '').contains(q);
}

/// +639171234567 -> 0917 123 4567
String prettyPhone(String e164) {
  if (e164.length != 13) return e164;
  final n = e164.substring(3);
  return '0${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
}
