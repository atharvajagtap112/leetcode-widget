import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // MethodChannel for pinning
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:leetcode_streak/Config/HomeWidgetConfig.dart';
import 'package:leetcode_streak/Config/adHelper.dart';
import 'package:leetcode_streak/Model/LeetcodeData.dart';
import 'package:leetcode_streak/Screens/ContributionCalendar.dart';
import 'package:leetcode_streak/Screens/username_Input.dart';
import 'package:leetcode_streak/Services/LeetCodeApi.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final bool launchedFromWidget;
  final VoidCallback? onRefreshDone;

  const HomeScreen({super.key, required this.launchedFromWidget, this.onRefreshDone});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _platform = MethodChannel('leetcode_streak/widgets');
  static const _prefsUsernameKey = 'username';
  static const _prefsDaysBackKey = 'daysBack';

  final TextEditingController _usernameController = TextEditingController();
  LeetCodeData? _leetCodeData;
  bool _isLoading = false;
  String? _errorMessage;
  BannerAd? bannerAd;

  // New: daysBack preference (default 365)
  int _daysBack = 365;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndMaybeFetch();

    BannerAd(
      size: AdSize.banner,
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          bannerAd = ad as BannerAd;
          setState(() {});
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Ad load failed (code=${error.code} message=${error.message})');
        },
      ),
    ).load();
  }

  Future<void> _loadPrefsAndMaybeFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString(_prefsUsernameKey);
    final savedDaysBack = prefs.getInt(_prefsDaysBackKey);

    if (savedDaysBack != null && savedDaysBack > 0) {
      _daysBack = savedDaysBack;
    }

    if (savedUsername != null && savedUsername.isNotEmpty) {
      _usernameController.text = savedUsername;
      _fetchLeetCodeData(savedUsername);
    } else {
      setState(() {}); // ensure selector shows the current state even if no username yet
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
        _errorMessage = null;

        if (bannerAd == null) {
          BannerAd(
            size: AdSize.banner,
            adUnitId: AdHelper.bannerAdUnitId,
            request: const AdRequest(),
            listener: BannerAdListener(
              onAdLoaded: (ad) {
                bannerAd = ad as BannerAd;
                setState(() {});
              },
              onAdFailedToLoad: (ad, error) {
                ad.dispose();
                debugPrint('Ad load failed (code=${error.code} message=${error.message})');
              },
            ),
          ).load();
        }
      });

      await _saveUsername(username);

      if (data != null && mounted) {
        await _updateWidgetImage(data);
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
    await prefs.setString(_prefsUsernameKey, username);
  }

  Future<void> _saveDaysBack(int daysBack) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsDaysBackKey, daysBack);
  }

  // Heuristic visuals based on selected range
  _CalendarVisuals _visualsForDaysBack(int daysBack) {
    // 365d: keep tighter cap so all months fit nicely.
    if (daysBack >= 365) {
      return const _CalendarVisuals(
        maxCellSizePx: 10.0,
        cellPaddingPx: 0.1,
        colSpacingPx: 1.0,
        rowSpacingPx: 1.0,
        monthGapPx: 3.0,
        radius: 1.0,
        monthLabelHeight: 14.0,
        horizontalPadding: 0.0,
        verticalPadding: 4.0,
      );
    }
    // ~6 months: allow slightly bigger max cells (auto-fit still prevents overflow)
    return const _CalendarVisuals(
      radius: 1.5,
      maxCellSizePx: 8.0,
      cellPaddingPx: 0.2,
      colSpacingPx: 1.8,
      rowSpacingPx: 1.8,
      monthGapPx: 4.0,
      monthLabelHeight: 14.0,
      horizontalPadding: 0.0,
      verticalPadding: 4.0,
    );
  }

  Future<void> _updateWidgetImage(LeetCodeData data) async {
    await Homewidgetconfig.initialize();
    final visuals = _visualsForDaysBack(_daysBack);

    await Homewidgetconfig.update(
      context,
      ContributionCalendar(
        radius: visuals.radius,
        data: data,
        mode: CalendarViewMode.rollingPastYear,
        daysBack: _daysBack,
        maxCellSizePx: visuals.maxCellSizePx,
        cellPaddingPx: visuals.cellPaddingPx,
        colSpacingPx: visuals.colSpacingPx,
        rowSpacingPx: visuals.rowSpacingPx,
        monthGapPx: visuals.monthGapPx,
        monthLabelHeight: visuals.monthLabelHeight,
        horizontalPadding: visuals.horizontalPadding,
        verticalPadding: visuals.verticalPadding,
      ),
    );
    widget.onRefreshDone?.call();

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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

    final visuals = _visualsForDaysBack(_daysBack);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF151A1E),
        elevation: 0,
        title: const Text('LeetStreak'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              if (bannerAd != null)
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: SizedBox(
                    width: bannerAd!.size.width.toDouble(),
                    height: bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: bannerAd!),
                  ),
                ),
              

              // Username + Fetch
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 5, 16, 8),
                child: _UsernameCard(
                  controller: _usernameController,
                  onSubmit: _fetchLeetCodeData,
                  cardColor: card,
                ),
              ),

              // New: Range selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _RangeSelectorCard(
                  cardColor: card,
                  daysBack: _daysBack,
                  onChanged: (value) async {
                    setState(() {
                      _daysBack = value;
                    });
                    await _saveDaysBack(value);

                    // If data already loaded, reflect selection in the pinned widget too
                    if (_leetCodeData != null && mounted) {
                      // No fetch needed; calendar will re-render with new daysBack automatically
                      await _updateWidgetImage(_leetCodeData!);
                    }
                  },
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
                // Stats
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _StatsRow(data: _leetCodeData!, cardColor: card),
                ),

                // Calendar (full-bleed)
                const SizedBox(height: 8),
                _FullBleedCalendar(
                  child: GestureDetector(
                    onTap: () {
                      if (_usernameController.text.isNotEmpty) {
                        _fetchLeetCodeData(_usernameController.text);
                      }
                    },
                    child: ContributionCalendar(
                      radius: visuals.radius,
                      data: _leetCodeData!,
                      mode: CalendarViewMode.rollingPastYear,
                      daysBack: _daysBack,
                      maxCellSizePx: visuals.maxCellSizePx,
                      cellPaddingPx: visuals.cellPaddingPx,
                      colSpacingPx: visuals.colSpacingPx,
                      rowSpacingPx: visuals.rowSpacingPx,
                      monthGapPx: visuals.monthGapPx,
                      monthLabelHeight: visuals.monthLabelHeight,
                      horizontalPadding: visuals.horizontalPadding,
                      verticalPadding: visuals.verticalPadding,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                const Center(
                  child: Text(
                    "Tap on the calendar to refresh",
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),

                // Actions
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
        ],
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
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                backgroundColor: const Color(0xFF0F1115),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.search, color: Colors.white),
              label: const Text('Fetch', style: TextStyle(color: Colors.white)),
              onPressed: () => onSubmit(controller.text),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _RangeSelectorCard extends StatelessWidget {
  final Color cardColor;
  final int daysBack;
  final ValueChanged<int> onChanged;

  const _RangeSelectorCard({
    super.key,
    required this.cardColor,
    required this.daysBack,
    required this.onChanged,
  });

  static const _chipTextStyle = TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final is365 = daysBack >= 365;
    final is182 = daysBack == 182;
   

    Widget buildChip(String label, bool selected, VoidCallback onTap) {
      return ChoiceChip(
        label: Text(label, style: _chipTextStyle),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: const Color(0xFF111418),
        selectedColor: const Color(0xFF059669),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Range', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              buildChip('1yr', is365, () => onChanged(365)),
              buildChip('6m', is182, () => onChanged(182)),  
        
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Your selection is saved automatically.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
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
    super.key,
    required this.data,
    required this.cardColor,
  });

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
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(5),
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

  const _FullBleedCalendar({super.key, required this.child});

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
    super.key,
    required this.message,
    required this.cardColor,
  });

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

// Tiny holder for calendar visual tweaks per range
class _CalendarVisuals {
  final double maxCellSizePx;
  final double cellPaddingPx;
  final double colSpacingPx;
  final double rowSpacingPx;
  final double monthGapPx;
  final double monthLabelHeight;
  final double horizontalPadding;
  final double verticalPadding;
  final double radius;

  const _CalendarVisuals({
    required this.maxCellSizePx,
    required this.cellPaddingPx,
    required this.colSpacingPx,

    required this.rowSpacingPx,
    required this.monthGapPx,
    required this.monthLabelHeight,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.radius,
  });
}