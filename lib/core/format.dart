import 'package:intl/intl.dart';
import 'models.dart';

final _money = NumberFormat('#,##0.##', 'en_US');
String taka(num v) => '৳${_money.format(v)}';
String shortTime(DateTime d) => DateFormat('h:mm a').format(d);
String dateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
String relative(DateTime? d) {
  if (d == null) return 'Never';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 45) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return DateFormat('d MMM').format(d);
}

String dayGroup(DateTime d) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(d.year, d.month, d.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('d MMM yyyy').format(d);
}

String statusLabel(TxStatus s) => switch (s) {
      TxStatus.verified => 'Verified',
      TxStatus.pending => 'Pending',
      TxStatus.unmatched => 'Unmatched',
      TxStatus.duplicate => 'Duplicate',
      TxStatus.unknown => 'Unknown',
    };
