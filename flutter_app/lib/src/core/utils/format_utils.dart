import 'package:intl/intl.dart';

/// Currency / number helpers for GoRento UI.
class FormatUtils {
  FormatUtils._();

  static final _vnd = NumberFormat('#,###', 'vi_VN');

  /// 1200000 → `1.200.000 ₫`
  static String vnd(dynamic value) {
    final n = _toNum(value);
    return '${_vnd.format(n.round())} ₫';
  }

  /// Compact daily rate: 1200000 → `1.200.000₫/ngày`
  static String vndPerDay(dynamic value) {
    final n = _toNum(value);
    return '${_vnd.format(n.round())}₫/ngày';
  }

  /// Parse user-typed price that may contain dots/commas/spaces.
  static double? parsePrice(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }
}
