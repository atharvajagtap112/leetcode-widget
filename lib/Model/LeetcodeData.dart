import 'dart:convert';

class LeetCodeData {
  final Map<String, dynamic> submissionCalendar;
  final int streak;
  final int totalActiveDays;
  final int year;

  LeetCodeData({
    required this.submissionCalendar, 
    required this.streak, 
    required this.totalActiveDays,
    required this.year,
  });
 
  String get submissionCalendarJson {
    return jsonEncode(submissionCalendar);
  }

  factory LeetCodeData.fromJson(Map<String, dynamic> json, int year) {
    final y1Data = json['data']['matchedUser']['y1'];

    // Parse submissionCalendar (stringified JSON map) to Map<String, dynamic>
    final calendarString = y1Data['submissionCalendar'];
    final calendarData = Map<String, dynamic>.from(
      Map<String, dynamic>.from(
        jsonDecode(calendarString),
      ),
    );

    return LeetCodeData(
      submissionCalendar: calendarData,
      streak: y1Data['streak'] ?? 0,           // (LeetCode returns "Max streak" for the year here)
      totalActiveDays: y1Data['totalActiveDays'] ?? 0,
      year: year,
    );
  }
}