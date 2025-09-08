import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LeetCodeProvider with ChangeNotifier {
  final SharedPreferences prefs;
  static const String _usernameKey = 'leetcode_username';
  
  String? _username;
  String? get username => _username;
  
  Map<DateTime, int>? _contributionData;
  Map<DateTime, int>? get contributionData => _contributionData;
  
  int _streak = 0;
  int get streak => _streak;
  
  int _totalActiveDays = 0;
  int get totalActiveDays => _totalActiveDays;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _error;
  String? get error => _error;
  
  int _currentYear = DateTime.now().year;
  int get currentYear => _currentYear;

  LeetCodeProvider(this.prefs) {
    _username = prefs.getString(_usernameKey);
    if (_username != null && _username!.isNotEmpty) {
      fetchUserData(_username!);
    }
  }

  void setYear(int year) {
    _currentYear = year;
    if (_username != null) {
      fetchUserData(_username!);
    }
    notifyListeners();
  }

  Future<bool> fetchUserData(String username) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await http.post(
        Uri.parse('https://leetcode.com/graphql'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "operationName": "UserCalendars",
          "variables": {
            "username": username,
            "y1": _currentYear,
            "y2": _currentYear - 1,
          },
          "query": '''
            query UserCalendars(\$username: String!, \$y1: Int!, \$y2: Int!) {
              matchedUser(username: \$username) {
                y1: userCalendar(year: \$y1) {
                  submissionCalendar
                  streak
                  totalActiveDays
                }
                y2: userCalendar(year: \$y2) {
                  submissionCalendar
                }
              }
            }
          '''
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['data']['matchedUser'] == null) {
          _error = 'User not found. Please check the username.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        // Parse y1 (current year) data
        final y1Data = data['data']['matchedUser']['y1'];
        _streak = y1Data['streak'] ?? 0;
        _totalActiveDays = y1Data['totalActiveDays'] ?? 0;
        
        final submissionCalendarData = json.decode(y1Data['submissionCalendar'] ?? '{}');
        _contributionData = {};
        
        submissionCalendarData.forEach((key, value) {
          final timestamp = int.parse(key) * 1000; // Convert to milliseconds
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          _contributionData![date] = value is int ? value : int.parse(value.toString());
        });
        
        // Store username in SharedPreferences
        await prefs.setString(_usernameKey, username);
        _username = username;
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to fetch data. Status code: ${response.statusCode}';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  int getMaxContributions() {
    if (_contributionData == null || _contributionData!.isEmpty) return 0;
    return _contributionData!.values.reduce((a, b) => a > b ? a : b);
  }

  List<int> getContributionThresholds() {
    final max = getMaxContributions();
    if (max <= 0) return [0, 0, 0, 0];
    
    // Dynamic thresholds based on user's activity distribution
    return [
      1,
      (max * 0.25).ceil(),
      (max * 0.5).ceil(),
      (max * 0.75).ceil(),
    ];
  }
}