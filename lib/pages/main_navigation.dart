import 'package:flutter/material.dart';
import 'daily_quiz_page.dart';
import 'favorin_hangisi_page.dart';
import 'profile_page.dart';
import '../unlimited_mode.dart';
import '../analytics/analytics_constants.dart';
import '../services/analytics_helper.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  late DateTime _tabEnteredAt;

  static const List<String> _tabNames = [
    AnalyticsScreenNames.home,
    AnalyticsScreenNames.favorin,
    AnalyticsScreenNames.unlimited,
    AnalyticsScreenNames.profile,
  ];

  final List<Widget> _pages = const [
    DailyQuizPage(),
    FavorinHangisiPage(),
    UnlimitedModePage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _tabEnteredAt = DateTime.now();
    AnalyticsNavigationState.setLastTabScreen(_tabNames[0]);
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    final oldName = _tabNames[_currentIndex];
    final ms = DateTime.now().difference(_tabEnteredAt).inMilliseconds;
    AnalyticsHelper.screenExit(screenName: oldName, durationMs: ms);
    setState(() {
      _currentIndex = index;
      _tabEnteredAt = DateTime.now();
    });
    final newName = _tabNames[index];
    AnalyticsNavigationState.setLastTabScreen(newName);
    AnalyticsHelper.screenView(screenName: newName, source: oldName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Günün Quizi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Favorin Hangisi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.all_inclusive),
            label: 'Sınırsız Mod',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
