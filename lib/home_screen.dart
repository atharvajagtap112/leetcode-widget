import 'dart:convert'; // reserved for future use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // MethodChannel for pinning
import 'package:leetcode_streak/Config/HomeWidgetConfig.dart';
import 'package:leetcode_streak/Model/LeetcodeData.dart';
import 'package:leetcode_streak/Screens/ContributionCalendar.dart';
import 'package:leetcode_streak/Screens/username_Input.dart';
import 'package:leetcode_streak/Services/LeetCodeApi.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _platform = MethodChannel('leetcode_streak/widgets');

  final TextEditingController _usernameController = TextEditingController();
  LeetCodeData? _leetCodeData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
  }

  Future<void> _loadSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    if (savedUsername != null && savedUsername.isNotEmpty) {
      _usernameController.text = savedUsername;
      _fetchLeetCodeData(savedUsername);
    }
  }

  Future<void> _fetchLeetCodeData(String username) async {
    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter a username');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await LeetCodeApi.fetchUserDataPastYear(username);
      setState(() {
        _leetCodeData = data;
        _isLoading = false;
      });

      await _saveUsername(username);

      if (data != null && mounted) {
        // Optional: render and push a fresh image to the widget
        await _updateWidgetImage(data);
      }
      else{
        setState(() {
        _errorMessage = 'User not found or error fetching data';
        _isLoading = false;
      });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'User not found or error fetching data';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<void> _updateWidgetImage(LeetCodeData data) async {
    await Homewidgetconfig.initialize();
    await Homewidgetconfig.update(
      context,
      ContributionCalendar(data: data),
      
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Widget image updated')),
    );
  }

  Future<void> _pinWidgetToHomeScreen() async {
    try {
      final ok = await _platform.invokeMethod<bool>('requestPinAppWidget') ?? false;
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pin request sent. Confirm on your home screen.')),
        );
      } else {
        // Launcher or Android version doesn’t support pinning. Show instructions.
        _showPinInstructions();
      }
    } catch (e) {
      if (!mounted) return;
      _showPinInstructions();
    }
  }

  void _showPinInstructions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151A1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Add widget manually',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            SizedBox(height: 8),
            Text(
              'Long-press your home screen → Widgets → find “LeetCode Streak Widget” → drag it to your home screen.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F1115);
    const card = Color(0xFF151A1E);
    const brand = Color(0xFF059669);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF151A1E), // Dark slate color in black family
        elevation: 0,
        title: const Text('LeetCode Streak Widget'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_usernameController.text.isNotEmpty) {
            await _fetchLeetCodeData(_usernameController.text);
          }
        },
        // No global horizontal padding so calendar can be edge-to-edge.
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Username + Fetch (padded section)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _UsernameCard(
                controller: _usernameController,
                onSubmit: _fetchLeetCodeData,
                cardColor: card,
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _ErrorCard(message: _errorMessage!, cardColor: card),
              )
            else if (_leetCodeData != null) ...[
              // Stats (padded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _StatsRow(data: _leetCodeData!, cardColor: card),
              ),

              // Calendar (FULL BLEED — no padding)
              const SizedBox(height: 8),
              _FullBleedCalendar(
                child: GestureDetector(
                  onTap: () {
                    if (_usernameController.text.isNotEmpty) {
                      _fetchLeetCodeData(_usernameController.text);
                    }
                  },
                  child: ContributionCalendar(data: _leetCodeData!),
                ),
              ),
              const SizedBox(height: 8),

              // Actions (only visible when data exists)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Row(
                  children: [
                  
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.push_pin_outlined),
                        label: const Text('Add to Home Screen'),
                        onPressed: _pinWidgetToHomeScreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}

class _UsernameCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final Color cardColor;

  const _UsernameCard({
    Key? key,
    required this.controller,
    required this.onSubmit,
    required this.cardColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UsernameInput(
            controller: controller,
           
          ),
          const SizedBox(height: 12),
            SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F1115), // Use your app's dark brand color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              ),
              icon: const Icon(Icons.search),
              label: const Text('Fetch'),
              onPressed: () => onSubmit(controller.text),
            ),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Pull down to refresh',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final LeetCodeData data;
  final Color cardColor;

  const _StatsRow({
    Key? key,
    required this.data,
    required this.cardColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _StatCard(title: 'Max streak', value: '${data.streak}', color: cardColor),
    
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(child: items[i]),
          if (i != items.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
     
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Edge-to-edge container so the calendar can use full width and avoid overflow.
class _FullBleedCalendar extends StatelessWidget {
  final Widget child;

  const _FullBleedCalendar({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return SizedBox(width: width, child: child);
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Color cardColor;

  const _ErrorCard({
    Key? key,
    required this.message,
    required this.cardColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}