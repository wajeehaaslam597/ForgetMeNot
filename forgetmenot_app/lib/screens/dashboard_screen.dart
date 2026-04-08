import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:forgetmenot/theme/app_theme.dart';
import 'package:forgetmenot/services/api_service.dart';
import 'package:forgetmenot/widgets/app_state.dart';
import 'package:forgetmenot/widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final pid = context.read<AppState>().currentPatientId;
    if (pid == null) return;
    try {
      final d = await ApiService.getDashboard(pid);
      setState(() { _data = d; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final greeting = _greeting();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primary,
        child: CustomScrollView(slivers: [
          // ── App Bar ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: AppTheme.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(greeting, style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                                Text(state.currentPatientName ?? 'Patient',
                                  style: const TextStyle(color: Colors.white,
                                    fontSize: 24, fontWeight: FontWeight.w800)),
                              ]),
                            AvatarPlaceholder(
                              name: state.currentPatientName ?? '?',
                              size: 52,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          DateFormat('EEEE, MMMM d').format(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Content ──────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(child: LoadingWidget(message: 'Loading dashboard...'))
          else if (_data == null)
            SliverFillRemaining(child: EmptyStateWidget(
              icon: Icons.wifi_off_rounded, title: 'Could not load',
              subtitle: 'Make sure your backend is running',
              buttonLabel: 'Retry', onButton: _load,
            ))
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(delegate: SliverChildListDelegate([
                // ── Today's Reminder Stats ────────────────────────────────
                _TodayRemindersCard(data: _data!['today_reminders'] ?? {}),
                const SizedBox(height: 20),
                // ── Quick Stats ───────────────────────────────────────────
                SectionHeader(title: 'Quick Stats'),
                const SizedBox(height: 14),
                _QuickStatsGrid(data: _data!),
                const SizedBox(height: 20),
                // ── Recent Activity ───────────────────────────────────────
                SectionHeader(title: 'Recent Activity'),
                const SizedBox(height: 14),
                _RecentActivityList(logs: (_data!['recent_logs'] as List?) ?? []),
                const SizedBox(height: 24),
              ])),
            ),
        ]),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _TodayRemindersCard extends StatelessWidget {
  final Map data;
  const _TodayRemindersCard({required this.data});

  @override
  Widget build(BuildContext context) => GradientCard(
    gradient: AppTheme.cardGradient,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.alarm_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        const Text("Today's Reminders", style: TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${data['total'] ?? 0} total',
            style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        _ReminderStat(label: 'Pending',   value: '${data['pending'] ?? 0}',   color: Colors.white),
        _ReminderStat(label: 'Completed', value: '${data['completed'] ?? 0}', color: const Color(0xFFB8F5D9)),
        _ReminderStat(label: 'Missed',    value: '${data['missed'] ?? 0}',    color: const Color(0xFFFFB3B3)),
      ]),
    ]),
  );
}

class _ReminderStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ReminderStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(
        color: color, fontSize: 30, fontWeight: FontWeight.w800, height: 1)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
        color: Colors.white.withOpacity(0.75), fontSize: 12)),
    ]),
  );
}

class _QuickStatsGrid extends StatelessWidget {
  final Map data;
  const _QuickStatsGrid({required this.data});

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.3, mainAxisSpacing: 12, crossAxisSpacing: 12,
    children: [
      StatTile(label: 'Visitors Registered', icon: Icons.people_rounded,
        value: '${data['visitor_count'] ?? 0}', color: AppTheme.secondary),
      StatTile(label: 'Pending Today', icon: Icons.pending_actions_rounded,
        value: '${data['today_reminders']?['pending'] ?? 0}', color: AppTheme.warning),
      StatTile(label: 'Completed Today', icon: Icons.check_circle_rounded,
        value: '${data['today_reminders']?['completed'] ?? 0}', color: AppTheme.success),
      StatTile(label: 'Missed Today', icon: Icons.cancel_rounded,
        value: '${data['today_reminders']?['missed'] ?? 0}', color: AppTheme.danger),
    ],
  );
}

class _RecentActivityList extends StatelessWidget {
  final List logs;
  const _RecentActivityList({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: const Center(child: Text('No activity yet',
        style: TextStyle(color: AppTheme.textLight))),
    );
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.softShadow),
      child: Column(
        children: logs.take(8).map((l) => _LogTile(log: l)).toList(),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final Map log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final type = log['event_type'] ?? '';
    final time = log['timestamp'] != null
      ? DateFormat('hh:mm a').format(DateTime.tryParse(log['timestamp']) ?? DateTime.now())
      : '';

    Color c; IconData icon;
    switch (type) {
      case 'reminder_triggered':
        c = AppTheme.warning; icon = Icons.alarm_rounded; break;
      case 'face_recognition':
        c = AppTheme.secondary; icon = Icons.face_rounded; break;
      case 'voice_command':
        c = AppTheme.primary; icon = Icons.mic_rounded; break;
      case 'tts_generated':
        c = AppTheme.accent; icon = Icons.volume_up_rounded; break;
      default:
        c = AppTheme.textLight; icon = Icons.circle_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: c.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: c, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(log['event_detail'] ?? type, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.textDark)),
            Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
          ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Text(log['result'] ?? '', style: TextStyle(
            fontSize: 10, color: c, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}