import 'package:flutter/material.dart';
import 'package:leetcode_streak/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const LeetCodeApp());
}

// Called when the widget is updated


class LeetCodeApp extends StatelessWidget {
  const LeetCodeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeetCode Streak Widget',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}