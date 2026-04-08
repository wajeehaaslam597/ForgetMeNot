import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:forgetmenot/theme/app_theme.dart';
import 'package:forgetmenot/services/api_service.dart';
import '/widgets/app_state.dart';
import 'package:forgetmenot/widgets/common_widgets.dart';
import 'home_screen.dart';

class PatientSelectScreen extends StatefulWidget {
  const PatientSelectScreen({super.key});
  @override
  State<PatientSelectScreen> createState() => _PatientSelectScreenState();
}

class _PatientSelectScreenState extends State<PatientSelectScreen> {
  List<dynamic> _patients = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await ApiService.listPatients();
      setState(() { _patients = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _selectPatient(Map p) async {
    await context.read<AppState>().setPatient(p['patient_id'], p['name']);
    if (mounted) Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _showAddPatient() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPatientSheet(onCreated: (p) {
        Navigator.pop(context);
        _selectPatient(p);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
      child: SafeArea(
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Column(children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 44),
              const SizedBox(height: 12),
              const Text('Welcome to ForgetMeNot',
                style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text('Select or create a patient profile to continue',
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          const SizedBox(height: 32),
          // ── List ───────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: _loading
                ? const LoadingWidget(message: 'Loading patients...')
                : _patients.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.person_add_rounded,
                      title: 'No Patients Yet',
                      subtitle: 'Create a patient profile to get started',
                      buttonLabel: '+ Add Patient',
                      onButton: _showAddPatient,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 100),
                      children: [
                        const Text('Select Patient', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppTheme.textLight, letterSpacing: 1,
                        )),
                        const SizedBox(height: 16),
                        ..._patients.map((p) => _PatientTile(
                          patient: p, onTap: () => _selectPatient(p),
                        )),
                      ],
                    ),
            ),
          ),
        ]),
      ),
    ),
    floatingActionButton: _patients.isNotEmpty ? FloatingActionButton.extended(
      onPressed: _showAddPatient,
      backgroundColor: AppTheme.primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Add Patient', style: TextStyle(
        color: Colors.white, fontWeight: FontWeight.w700)),
    ) : null,
  );
}

class _PatientTile extends StatelessWidget {
  final Map patient;
  final VoidCallback onTap;
  const _PatientTile({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(children: [
        AvatarPlaceholder(name: patient['name'] ?? '?', size: 52),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(patient['name'] ?? 'Unknown', style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          if (patient['age'] != null)
            Text('Age ${patient['age']} • ${patient['relationship'] ?? ''}',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMid)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textLight),
      ]),
    ),
  );
}

class _AddPatientSheet extends StatefulWidget {
  final Function(Map) onCreated;
  const _AddPatientSheet({required this.onCreated});
  @override State<_AddPatientSheet> createState() => _AddPatientSheetState();
}

class _AddPatientSheetState extends State<_AddPatientSheet> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl  = TextEditingController();
  String _relation = 'Parent';
  bool _saving = false;
  static const _relations = ['Parent', 'Spouse', 'Sibling', 'Child', 'Friend', 'Other'];

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final res = await ApiService.createPatient(
        name: _nameCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text),
        relationship: _relation,
      );
      widget.onCreated(res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(24, 24, 24,
      24 + MediaQuery.of(context).viewInsets.bottom),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('New Patient', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          IconButton(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 20),
        TextField(controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Full Name',
            prefixIcon: Icon(Icons.person_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _ageCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Age',
            prefixIcon: Icon(Icons.cake_rounded))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _relation,
          items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => _relation = v!),
          decoration: const InputDecoration(labelText: 'Your Relationship',
            prefixIcon: Icon(Icons.family_restroom_rounded)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Create Profile'),
          ),
        ),
      ],
    ),
  );
}