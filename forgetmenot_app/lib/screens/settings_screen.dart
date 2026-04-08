import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:forgetmenot/theme/app_theme.dart';
import 'package:forgetmenot/services/api_service.dart';
import 'package:forgetmenot/widgets/app_state.dart';
import 'package:forgetmenot/widgets/common_widgets.dart';
import 'patient_select_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _settings;
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final pid = context.read<AppState>().currentPatientId;
    if (pid == null) return;
    try {
      final s = await ApiService.getSettings(pid);
      setState(() { _settings = Map<String, dynamic>.from(s); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _save() async {
    final pid = context.read<AppState>().currentPatientId;
    if (pid == null || _settings == null) return;
    setState(() => _saving = true);
    try {
      await ApiService.updateSettings(pid,
        language:        _settings!['language'] ?? 'en',
        autoRecognition: _settings!['auto_recognition'] ?? true,
        cooldown:        _settings!['recognition_cooldown_seconds'] ?? 60,
        snoozeMins:      _settings!['reminder_snooze_minutes'] ?? 5,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white, title: const Text('Settings'), elevation: 0),
      body: _loading
        ? const LoadingWidget()
        : ListView(padding: const EdgeInsets.all(20), children: [
          // ── Patient Info ──────────────────────────────────────────────
          _Section('Patient', [
            _InfoTile('Current Patient', state.currentPatientName ?? 'Unknown',
              Icons.person_rounded, AppTheme.primary),
            _TapTile('Switch Patient', Icons.swap_horiz_rounded, AppTheme.accent,
              onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const PatientSelectScreen()))),
          ]),
          const SizedBox(height: 20),
          // ── App Settings ──────────────────────────────────────────────
          if (_settings != null) ...[
            _Section('App Settings', [
              _ToggleTile('Language: Urdu',
                Icons.language_rounded, AppTheme.secondary,
                _settings!['language'] == 'ur',
                (v) => setState(() => _settings!['language'] = v ? 'ur' : 'en')),
              _ToggleTile('Auto Face Recognition',
                Icons.face_rounded, AppTheme.primary,
                _settings!['auto_recognition'] ?? true,
                (v) => setState(() => _settings!['auto_recognition'] = v)),
              _SliderTile('Recognition Cooldown',
                Icons.timer_rounded, AppTheme.warning,
                (_settings!['recognition_cooldown_seconds'] ?? 60).toDouble(),
                10, 300, 'seconds',
                (v) => setState(() =>
                  _settings!['recognition_cooldown_seconds'] = v.round())),
              _SliderTile('Snooze Duration',
                Icons.snooze_rounded, AppTheme.danger,
                (_settings!['reminder_snooze_minutes'] ?? 5).toDouble(),
                1, 30, 'minutes',
                (v) => setState(() =>
                  _settings!['reminder_snooze_minutes'] = v.round())),
            ]),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Settings'),
              )),
          ],
          const SizedBox(height: 40),
        ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: AppTheme.textLight, letterSpacing: 0.8)),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow),
        child: Column(children: children),
      ),
    ],
  );
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _InfoTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18)),
    title: Text(label, style: const TextStyle(fontSize: 14,
      fontWeight: FontWeight.w600, color: AppTheme.textMid)),
    subtitle: Text(value, style: const TextStyle(fontSize: 15,
      fontWeight: FontWeight.w700, color: AppTheme.textDark)),
  );
}

class _TapTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TapTile(this.label, this.icon, this.color, {required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18)),
    title: Text(label, style: const TextStyle(fontSize: 15,
      fontWeight: FontWeight.w600, color: AppTheme.textDark)),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14,
      color: AppTheme.textLight),
  );
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool value;
  final Function(bool) onChanged;
  const _ToggleTile(this.label, this.icon, this.color, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18)),
    title: Text(label, style: const TextStyle(fontSize: 15,
      fontWeight: FontWeight.w600, color: AppTheme.textDark)),
    trailing: Switch(value: value, onChanged: onChanged, activeColor: color),
  );
}

class _SliderTile extends StatelessWidget {
  final String label, unit;
  final IconData icon;
  final Color color;
  final double value, min, max;
  final Function(double) onChanged;
  const _SliderTile(this.label, this.icon, this.color, this.value, this.min,
    this.max, this.unit, this.onChanged);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15,
          fontWeight: FontWeight.w600, color: AppTheme.textDark))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text('${value.round()} $unit', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
      Slider(value: value, min: min, max: max, onChanged: onChanged,
        activeColor: color),
    ]),
  );
}