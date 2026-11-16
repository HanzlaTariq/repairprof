import 'package:intl/intl.dart';

typedef Json = Map<String, dynamic>;
const statuses = [
  'Received',
  'Checking',
  'Awaiting Approval',
  'Repairing',
  'Ready for Pickup',
  'Ready for Return',
  'Delivered',
];
String money(dynamic value) => NumberFormat.currency(
  locale: 'en_PK',
  symbol: 'PKR ',
  decimalDigits: 2,
).format(((value as num?) ?? 0) / 100);
String dateText(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '—';
  return '${DateFormat('dd MMM yyyy, h:mm a').format(parsed.toUtc().add(const Duration(hours: 5)))} PKT';
}

int minor(String text) {
  final cleaned = text.trim();
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(cleaned)) {
    throw const FormatException(
      'Enter a valid rupee amount with up to 2 decimals.',
    );
  }
  final parts = cleaned.split('.');
  return int.parse(parts[0]) * 100 +
      int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
}

List<Json> maps(dynamic value) => ((value as List?) ?? [])
    .map((v) => Map<String, dynamic>.from(v as Map))
    .toList();
Json map(dynamic value) => Map<String, dynamic>.from((value as Map?) ?? {});
