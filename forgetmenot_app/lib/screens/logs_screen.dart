import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:forgetmenot/theme/app_theme.dart';
import 'package:forgetmenot/services/api_service.dart';
import 'package:forgetmenot/widgets/app_state.dart';
import 'package:forgetmenot/widgets/common_widgets.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<dynamic> _logs = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _filter;

  static const _filters = [
    null,
    'reminder_triggered',
    'face_recognition',
    'voice_command',
    'tts_generated',
    'reminder_status',
    'visitor_added',
  ];

  static const _filterLabels = [
    'All',
    'Reminders',
    'Face Scan',
    'Voice',
    'TTS',
    'Status',
    'Visitors',
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final pid = context.read<AppState>().currentPatientId;
    if (pid == null) return;
    try {
      final logs = await ApiService.getLogs(pid, eventType: _filter);
      final sum  = await ApiService.getLogSummary(pid);
      setState(() { _logs = logs; _summary = sum; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.surface,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Activity Logs'),
      elevation: 0,
    ),
    body: Column(children: [
      // ── Summary Banner ──────────────────────────────────────────────────
      if (_summary != null)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _SumChip('Total Logs', '${_summary!['total_logs']}', AppTheme.primary),
              _SumChip("Today's Logs", '${_summary!['today_logs']}', AppTheme.accent),
              _SumChip('Face Success', '${_summary!['face_recognitions_success']}',
                AppTheme.secondary),
              _SumChip('Reminders Done', '${_summary!['reminders_completed']}',
                AppTheme.success),
              _SumChip('Missed', '${_summary!['reminders_missed']}', AppTheme.danger),
            ]),
          ),
        ),

      // ── Filter Chips ────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(_filters.length, (i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_filterLabels[i]),
                selected: _filter == _filters[i],
                onSelected: (_) {
                  setState(() { _filter = _filters[i]; _loading = true; });
                  _load();
                },
                selectedColor: AppTheme.primary.withOpacity(0.15),
                checkmarkColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: _filter == _filters[i] ? AppTheme.primary : AppTheme.textMid,
                  fontWeight: FontWeight.w600, fontSize: 12,
                ),
              ),
            )),
          ),
        ),
      ),
      const Divider(height: 1, color: AppTheme.divider),

      // ── List ─────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
          ? const LoadingWidget(message: 'Loading logs...')
          : _logs.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.history_rounded,
                title: 'No logs yet',
                subtitle: 'Activity will appear here as the patient uses the app',
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.primary,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LogCard(log: _logs[i]),
                ),
              ),
      ),
    ]),
  );
}

class _SumChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(
        fontSize: 10, color: AppTheme.textMid, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _LogCard extends StatelessWidget {
  final Map log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final type = log['event_type'] ?? '';
    final ts   = log['timestamp'] != null
      ? DateFormat('MMM d, hh:mm:ss a')
          .format(DateTime.tryParse(log['timestamp']) ?? DateTime.now())
      : '';

    Color c; IconData icon;
    switch (type) {
      case 'reminder_triggered':
        c = AppTheme.warning;   icon = Icons.alarm_rounded;          break;
      case 'reminder_status':
        c = AppTheme.success;   icon = Icons.check_circle_rounded;   break;
      case 'face_recognition':
        c = AppTheme.secondary; icon = Icons.face_rounded;           break;
      case 'voice_command':
        c = AppTheme.primary;   icon = Icons.mic_rounded;            break;
      case 'tts_generated':
        c = AppTheme.accent;    icon = Icons.volume_up_rounded;      break;
      case 'visitor_added':
        c = AppTheme.primaryDark; icon = Icons.person_add_rounded;   break;
      default:
        c = AppTheme.textLight; icon = Icons.info_outline_rounded;
    }

    final result = log['result'] ?? '';
    Color resultColor;
    switch (result) {
      case 'success': resultColor = AppTheme.success; break;
      case 'error':   resultColor = AppTheme.danger;  break;
      case 'triggered':
      case 'ok':      resultColor = AppTheme.secondary; break;
      default:        resultColor = AppTheme.textMid;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(
            color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: c, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(_formatType(type), style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark))),
              if (result.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(result, style: TextStyle(
                    fontSize: 10, color: resultColor, fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 3),
            Text(log['event_detail'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
            const SizedBox(height: 4),
            Text(ts, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
          ]),
        ),
      ]),
    );
  }

  String _formatType(String t) => t.replaceAll('_', ' ')
    .split(' ').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
    .join(' ');
}