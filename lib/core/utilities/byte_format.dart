/// Formats a byte count for display, for example `2.4 MB` or `812 KB`.
String formatBytes(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final String amount = unitIndex == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(value >= 100 ? 0 : 1);
  return '$amount ${units[unitIndex]}';
}
