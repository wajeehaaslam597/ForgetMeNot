import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:forgetmenot/theme/app_theme.dart';
import 'package:forgetmenot/services/api_service.dart';
import 'package:forgetmenot/widgets/app_state.dart';
import 'package:forgetmenot/widgets/common_widgets.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});
  @override State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  final _cmdCtrl = TextEditingController();
  bool _loading  = false;
  String _lang   = 'en';
  Map<String, dynamic>? _result;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  static const _quickCommands = [
    "What are my reminders?",
    "What time is it?",
    "What is today's date?",
    "Who are you?",
    "Call my caregiver",
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); _cmdCtrl.dispose(); super.dispose(); }

  Future<void> _send(String cmd) async {
    if (cmd.trim().isEmpty) return;
    final pid = context.read<AppState>().currentPatientId;
    if (pid == null) return;
    setState(() { _loading = true; _result = null; });
    try {
      final res = await ApiService.voiceCommandResponse(
        command: cmd, patientId: pid, language: _lang);
      setState(() => _result = res);
    } catch (e) {
      setState(() => _result = {'error': e.toString()});
    } finally {
      setState(() => _loading = false);
      _cmdCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.surface,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Voice Assistant'),
      elevation: 0,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Row(children: [
            const Text('EN', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMid)),
            Switch(
              value: _lang == 'ur',
              onChanged: (v) => setState(() => _lang = v ? 'ur' : 'en'),
              activeColor: AppTheme.primary,
            ),
            const Text('UR', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMid)),
          ]),
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // ── Hero ─────────────────────────────────────────────────────────
        GradientCard(
          gradient: AppTheme.primaryGradient,
          child: Column(children: [
            ScaleTransition(
              scale: _loading ? _pulse : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _loading ? Icons.hourglass_top_rounded : Icons.mic_rounded,
                  color: Colors.white, size: 38,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _loading ? 'Listening...' : 'Ask me anything',
              style: const TextStyle(color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Language: ${_lang == "en" ? "English (Jenny)" : "Urdu (Uzma)"}',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        // ── Quick Commands ───────────────────────────────────────────────
        SectionHeader(title: 'Quick Commands'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8,
          children: _quickCommands.map((cmd) => GestureDetector(
            onTap: () { _cmdCtrl.text = cmd; _send(cmd); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.accent),
                const SizedBox(width: 4),
                Text(cmd, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              ]),
            ),
          )).toList(),
        ),

        const SizedBox(height: 24),

        // ── Response Card ───────────────────────────────────────────────
        if (_loading)
          const LoadingWidget(message: 'Getting response...')
        else if (_result != null) ...[
          SectionHeader(title: 'Response'),
          const SizedBox(height: 12),
          _ResponseCard(result: _result!),
          const SizedBox(height: 24),
        ],

        // ── Text Input ───────────────────────────────────────────────────
        SectionHeader(title: 'Type a Command'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _cmdCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. What time is it?',
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
              ),
              onSubmitted: _send,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: IconButton(
              onPressed: _loading ? null : () => _send(_cmdCtrl.text),
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ]),
        const SizedBox(height: 40),
      ]),
    ),
  );
}

class _ResponseCard extends StatelessWidget {
  final Map result;
  const _ResponseCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result['error'] != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
          const SizedBox(width: 12),
          Expanded(child: Text('Error: ${result['error']}',
            style: const TextStyle(color: AppTheme.danger))),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          const Text('Response', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
        ]),
        const SizedBox(height: 12),
        Text(result['response_text'] ?? '',
          style: const TextStyle(fontSize: 16, height: 1.5, color: AppTheme.textDark,
            fontWeight: FontWeight.w500)),
        if (result['audio_url'] != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.volume_up_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Audio available at: ${result['audio_url']}',
                style: const TextStyle(fontSize: 11, color: AppTheme.primary,
                  fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
        if (result['command'] != null) ...[
          const SizedBox(height: 10),
          Text('You asked: "${result['command']}"',
            style: const TextStyle(fontSize: 12, color: AppTheme.textLight,
              fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}