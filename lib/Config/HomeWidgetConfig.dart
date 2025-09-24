import 'dart:io';

import 'package:davinci/core/davinci_capture.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:leetcode_streak/Screens/ContributionCalendar.dart';
import 'package:leetcode_streak/constants/string.dart';
import 'package:path_provider/path_provider.dart';

class Homewidgetconfig {
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(groupId);
  }

  static Future<void> update(BuildContext context, ContributionCalendar calendar) async {
    try {
      final result = await DavinciCapture.offStage(
        calendar,
        context: context,
        returnImageUint8List: true,
        openFilePreview: false,
        wait: const Duration(milliseconds: 300),
      );

      // Ensure we have bytes and the type is what we expect
      if (result is! Uint8List || result.isEmpty) {
        debugPrint('Homewidgetconfig.update: capture returned no/invalid bytes (type: ${result.runtimeType})');
        return;
      }

      // Upcast to List<int> for File.writeAsBytes (Uint8List implements List<int>)
      final List<int> bytes = result;

      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/leetcode_calendar.png');

      await file.writeAsBytes(bytes, flush: true);

      await HomeWidget.saveWidgetData('filename', file.path);
      await HomeWidget.updateWidget(
        iOSName: iosWidget,
        androidName: androidWidget,
      );
    } catch (e, st) {
      debugPrint('Homewidgetconfig.update error: $e\n$st');
      rethrow;
    }
  }
}