// lib/utils/string_utils.dart
String safeInitials(String? name, {int max = 2}) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return 'NA';

  final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  String out = '';
  for (final p in parts) {
    if (out.length >= max) break;
    out += p[0];
  }
  if (out.isEmpty) out = n[0];
  return out.toUpperCase();
}
