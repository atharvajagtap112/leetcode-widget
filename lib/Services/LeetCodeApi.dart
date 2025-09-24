import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:leetcode_streak/Model/LeetcodeData.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeetCodeApi {
  static const String _baseUrl = 'https://leetcode.com/graphql';
  static const String _usernameKey = 'leetcode_username';

  static Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  // Past 365 days (rolling window) ending at now (UTC).
  // This fetches both the current year (y1) and previous year (y0) calendars in ONE request,
  // merges and filters them to the [now-364d, now] window, then injects that merged
  // calendar back into jsonData so your existing LeetCodeData.fromJson still works.
  static Future<LeetCodeData?> fetchUserDataPastYear(String username) async {
    try {
      final now = DateTime.now().toUtc();
      final y1 = now.year;
      final y0 = y1 - 1;

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: const {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({
          "operationName": "UserCalendars",
          "variables": {
            "username": username,
            "y1": y1,
            "y0": y0,
          },
          "query": """
query UserCalendars(\$username: String!, \$y1: Int!, \$y0: Int!) {
  matchedUser(username: \$username) {
    y0: userCalendar(year: \$y0) { submissionCalendar }
    y1: userCalendar(year: \$y1) { submissionCalendar streak totalActiveDays }
  }
}
""",
        }),
      );

      if (response.statusCode != 200) return null;

      final jsonData = jsonDecode(response.body);
      final matched = jsonData['data']?['matchedUser'];
      if (matched == null) return null;

      // Decode both calendars (they come back as JSON string maps: { "ts": count, ... })
      Map<String, int> decodeCal(dynamic node) {
        if (node == null) return {};
        final sc = node['submissionCalendar'];
        if (sc is String && sc.isNotEmpty) {
          final m = Map<String, dynamic>.from(jsonDecode(sc));
          return m.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        }
        return {};
      }

      final cal0 = decodeCal(matched['y0']);
      final cal1 = decodeCal(matched['y1']);

      // Merge and filter to last 365 days
      final merged = <String, int>{}..addAll(cal0)..addAll(cal1);

      final start = now.subtract(const Duration(days: 364));
      final startTs = start.millisecondsSinceEpoch ~/ 1000;
      final endTs = now.millisecondsSinceEpoch ~/ 1000;

      merged.removeWhere((k, _) {
        final ts = int.tryParse(k) ?? -1;
        return ts < startTs || ts > endTs;
      });

      // Re-encode and inject back for your existing model parser
      matched['y1']['submissionCalendar'] = jsonEncode(merged);

      // Save the valid username
      await saveUsername(username);

      // We pass y1 (current year) as display year; the calendar widget will ignore the year
      // and render the rolling window based on timestamps.
      return LeetCodeData.fromJson(jsonData, y1);
    } catch (e) {
      debugPrint('Error fetching LeetCode past-year data: $e');
      return null;
    }
  }

  // Keep the original yearly method if you still need it elsewhere.
  static Future<LeetCodeData?> fetchUserDataYear(String username, int year) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: const {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({
          "operationName": "UserCalendars",
          "variables": {
            "username": username,
            "y1": year,
          },
          "query": "query UserCalendars(\$username: String!, \$y1: Int!) { matchedUser(username: \$username) { y1: userCalendar(year: \$y1) { submissionCalendar streak totalActiveDays } } }",
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['data']['matchedUser'] == null) return null;
        await saveUsername(username);
        return LeetCodeData.fromJson(jsonData, year);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching LeetCode yearly data: $e');
      return null;
    }
  }
}