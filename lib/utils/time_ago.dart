/// Compact relative-time formatting, e.g. "3d ago", "just now".
String timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.isNegative) return 'just now';
  if (d.inDays >= 365) return '${(d.inDays / 365).floor()}y ago';
  if (d.inDays >= 30) return '${(d.inDays / 30).floor()}mo ago';
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
  return 'just now';
}
