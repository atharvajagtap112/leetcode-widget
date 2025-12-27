import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:leetcode_streak/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   final Uri? intialUri =await HomeWidget.initiallyLaunchedFromHomeWidget();
  final bool lauchedFromWidget= intialUri?.host=="refresh"; 

  runApp(LeetCodeApp(lauchedFromWidget: lauchedFromWidget));
}



class LeetCodeApp extends StatelessWidget {
  final bool lauchedFromWidget;
  const LeetCodeApp({super.key, required this.lauchedFromWidget});

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
      home:  HomeScreen(
        launchedFromWidget: lauchedFromWidget,
        onRefreshDone: (){
          if(lauchedFromWidget){
            SystemNavigator.pop();
          }
        },
      ),
    );
  }
}