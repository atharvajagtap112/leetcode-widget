import 'package:shared_preferences/shared_preferences.dart';

enum WidgetViewMode {
  year365(days: 365, displayName: "1 Year"),
  months6(days: 183, displayName: "6 Months"),
  months3(days: 92, displayName: "3 Months");

  const WidgetViewMode({
    required this.days,
    required this.displayName,
  });

  final int days;
  final String displayName;
}

class WidgetConfig {
  static const String _keyViewMode = 'widget_view_mode';
  static const String _keyCellSize = 'widget_cell_size';
  static const String _keyUsername = 'username';

  static Future<WidgetViewMode> getViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_keyViewMode) ?? 0;
    return WidgetViewMode.values[modeIndex.clamp(0, WidgetViewMode.values.length - 1)];
  }

  static Future<void> setViewMode(WidgetViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyViewMode, mode.index);
  }

  static Future<double> getCellSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyCellSize) ?? 12.0;
  }

  static Future<void> setCellSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCellSize, size);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<void> setUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }

  // Calculate optimal cell size based on widget dimensions and view mode
  static double calculateOptimalCellSize(WidgetViewMode mode, double widgetWidth) {
    late int approximateWeeks;
    
    switch (mode) {
      case WidgetViewMode.year365:
        approximateWeeks = 53; // ~365/7
        break;
      case WidgetViewMode.months6:
        approximateWeeks = 26; // ~183/7
        break;
      case WidgetViewMode.months3:
        approximateWeeks = 13; // ~92/7
        break;
    }

    // Account for spacing and padding
    final availableWidth = widgetWidth - 32; // Padding
    final spacingWidth = (approximateWeeks - 1) * 1.0; // Column spacing
    final cellWidth = (availableWidth - spacingWidth) / approximateWeeks;
    
    return (cellWidth - 0.4).clamp(8.0, 16.0); // Min 8px, Max 16px
  }
}