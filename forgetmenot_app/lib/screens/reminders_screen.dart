import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:forgetmenot/theme/app_theme.dart';
import 'package:forgetmenot/services/api_service.dart';
import 'package:forgetmenot/widgets/app_state.dart';
import 'package:forgetmenot/widgets/common_widgets.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    final pid = context.read<AppState>().currentPatientId;
    if (pid == null) return;
    try {
      final data = await ApiService.getReminders(pid);
      setState(() { _all = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  List get _pending   => _all.where((r) => r['status'] == 'pending').toList();
  List get _completed => _all.where((r) => r['status'] == 'completed').toList();
  List get _missed    => _all.where((r) => r['status'] == 'missed').toList();

  void _showAddReminder() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddReminderSheet(
        patientId: context.read<AppState>().currentPatientId!,
        onCreated: (_) { Navigator.pop(context); _load(); },
      ));
  }

  Future<void> _updateStatus(String rid, String status) async {
    try {
      await ApiService.updateReminderStatus(rid, status);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.surface,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Reminders'),
      elevation: 0,
      bottom: TabBar(
        controller: _tabs,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textLight,
        indicatorColor: AppTheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: [
          Tab(text: 'Pending (${_pending.length})'),
          Tab(text: 'Done (${_completed.length})'),
          Tab(text: 'Missed (${_missed.length})'),
        ],
      ),
    ),
    body: _loading
      ? const LoadingWidget(message: 'Loading reminders...')
      : TabBarView(controller: _tabs, children: [
          _ReminderList(reminders: _pending,   onAction: _updateStatus, showActions: true),
          _ReminderList(reminders: _completed, onAction: _updateStatus, showActions: false),
          _ReminderList(reminders: _missed,    onAction: _updateStatus, showActions: false),
        ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showAddReminder,
      backgroundColor: AppTheme.primary,
      icon: const Icon(Icons.add_alarm_rounded, color: Colors.white),
      label: const Text('Add Reminder',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    ),
  );
}

class _ReminderList extends StatelessWidget {
  final List reminders;
  final Function(String, String) onAction;
  final bool showActions;
  const _ReminderList({required this.reminders, required this.onAction,
    required this.showActions});

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return EmptyStateWidget(
      icon: Icons.alarm_off_rounded,
      title: 'No reminders here',
      subtitle: 'All clear in this category',
    );
    return RefreshIndicator(
      onRefresh: () async {},
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: reminders.length,
        itemBuilder: (_, i) => _ReminderCard(
          reminder: reminders[i],
          onAction: onAction,
          showActions: showActions,
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Map reminder;
  final Function(String, String) onAction;
  final bool showActions;
  const _ReminderCard({required this.reminder, required this.onAction,
    required this.showActions});

  @override
  Widget build(BuildContext context) {
    final type  = reminder['reminder_type'] ?? 'custom';
    final color = AppTheme.reminderColor(type);
    final icon  = AppTheme.reminderIcon(type);
    final time  = reminder['scheduled_time'] != null
      ? DateFormat('MMM d, hh:mm a')
          .format(DateTime.tryParse(reminder['scheduled_time']) ?? DateTime.now())
      : '';
    final repeat = reminder['repeat_option'] ?? 'one-time';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder['title'] ?? '', style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                Text(time, style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
              ])),
            ReminderStatusChip(status: reminder['status'] ?? 'pending'),
          ]),
          if (reminder['voice_message'] != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.volume_up_rounded, size: 14, color: AppTheme.textLight),
              const SizedBox(width: 4),
              Expanded(child: Text(reminder['voice_message'],
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMid))),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            _Tag(Icons.repeat_rounded, repeat),
            const SizedBox(width: 8),
            _Tag(icon, type),
            if (showActions) ...[
              const Spacer(),
              _ActionBtn(label: 'Done', color: AppTheme.success,
                onTap: () => onAction(reminder['reminder_id'], 'completed')),
              const SizedBox(width: 6),
              _ActionBtn(label: 'Miss', color: AppTheme.danger,
                onTap: () => onAction(reminder['reminder_id'], 'missed')),
              const SizedBox(width: 6),
              _ActionBtn(label: 'Snooze', color: AppTheme.warning,
                onTap: () => onAction(reminder['reminder_id'], 'snoozed')),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: AppTheme.primary),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(
        fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(
        fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    ),
  );
}

// ── Add Reminder Sheet ─────────────────────────────────────────────────────
class _AddReminderSheet extends StatefulWidget {
  final String patientId;
  final Function(Map) onCreated;
  const _AddReminderSheet({required this.patientId, required this.onCreated});
  @override State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _titleCtrl   = TextEditingController();
  final _msgCtrl     = TextEditingController();
  String _type       = 'medication';
  String _repeat     = 'one-time';
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));
  bool _saving       = false;

  static const _types   = ['medication', 'meal', 'appointment', 'custom'];
  static const _repeats = ['one-time', 'daily', 'weekly'];

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(context: context,
      initialDate: _dateTime, firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null) return;
    final t = await showTimePicker(context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime));
    if (t == null) return;
    setState(() => _dateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final res = await ApiService.createReminder(
        patientId:     widget.patientId,
        title:         _titleCtrl.text.trim(),
        reminderType:  _type,
        scheduledTime: _dateTime.toIso8601String(),
        repeatOption:  _repeat,
        voiceMessage:  _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
      );
      widget.onCreated(res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.85,
    padding: EdgeInsets.fromLTRB(24, 24, 24,
      24 + MediaQuery.of(context).viewInsets.bottom),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('New Reminder', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          IconButton(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 20),
        TextField(controller: _titleCtrl,
          decoration: const InputDecoration(labelText: 'Reminder Title',
            prefixIcon: Icon(Icons.title_rounded))),
        const SizedBox(height: 12),
        // Type
        const Text('Type', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: _types.map((t) => ChoiceChip(
          label: Text(t[0].toUpperCase() + t.substring(1)),
          selected: _type == t,
          selectedColor: AppTheme.primary.withOpacity(0.15),
          onSelected: (_) => setState(() => _type = t),
        )).toList()),
        const SizedBox(height: 12),
        // Date & Time
        GestureDetector(
          onTap: _pickDateTime,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.divider),
              borderRadius: BorderRadius.circular(16), color: Colors.white),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Date & Time', style: TextStyle(
                  fontSize: 12, color: AppTheme.textMid)),
                Text(DateFormat('MMM d, yyyy – hh:mm a').format(_dateTime),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppTheme.textDark)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // Repeat
        const Text('Repeat', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: _repeats.map((r) => ChoiceChip(
          label: Text(r[0].toUpperCase() + r.substring(1)),
          selected: _repeat == r,
          selectedColor: AppTheme.primary.withOpacity(0.15),
          onSelected: (_) => setState(() => _repeat = r),
        )).toList()),
        const SizedBox(height: 12),
        TextField(controller: _msgCtrl, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Voice Message (optional)',
            prefixIcon: Icon(Icons.volume_up_rounded),
            hintText: 'What should I say aloud?')),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Schedule Reminder'),
          )),
      ]),
    ),
  );
}