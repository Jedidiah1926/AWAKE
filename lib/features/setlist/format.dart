const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// "2026. 10. 4. (일)"
String formatDate(DateTime date) =>
    '${date.year}. ${date.month}. ${date.day}. (${_weekdays[date.weekday - 1]})';

/// 다가오는 일요일 (오늘이 일요일이면 오늘). 새 콘티 기본 날짜.
DateTime nextSunday(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.add(Duration(days: (DateTime.sunday - today.weekday) % 7));
}
