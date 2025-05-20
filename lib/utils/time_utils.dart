String formatTime(int minutes) {
  final int hours = minutes ~/ 60;
  final int remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}m';
}
