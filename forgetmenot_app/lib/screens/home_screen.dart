import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:forgetmenot/theme/app_theme.dart';
import 'package:forgetmenot/widgets/app_state.dart';
import 'dashboard_screen.dart';
import 'reminders_screen.dart';
import 'visitors_screen.dart';
import 'voice_screen.dart';
import 'logs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.alarm_rounded),     label: 'Reminders'),
    BottomNavigationBarItem(icon: Icon(Icons.face_rounded),      label: 'Faces'),
    BottomNavigationBarItem(icon: Icon(Icons.mic_rounded),       label: 'Voice'),
    BottomNavigationBarItem(icon: Icon(Icons.history_rounded),   label: 'Logs'),
  ];

  Widget _screen() {
    switch (_index) {
      case 0: return const DashboardScreen();
      case 1: return const RemindersScreen();
      case 2: return const VisitorsScreen();
      case 3: return const VoiceScreen();
      case 4: return const LogsScreen();
      default: return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: _screen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) => _NavItem(
                item: _items[i],
                selected: _index == i,
                onTap: () => setState(() => _index = i),
              )),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final BottomNavigationBarItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedTheme(
          data: ThemeData(iconTheme: IconThemeData(
            color: selected ? AppTheme.primary : AppTheme.textLight, size: 22,
          )),
          child: item.icon,
        ),
        const SizedBox(height: 3),
        Text(item.label ?? '', style: TextStyle(
          fontSize: 10,
          color: selected ? AppTheme.primary : AppTheme.textLight,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        )),
      ]),
    ),
  );
}