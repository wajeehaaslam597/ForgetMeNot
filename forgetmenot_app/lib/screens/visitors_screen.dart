import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:forgetmenot/theme/app_theme.dart';
import 'package:forgetmenot/services/api_service.dart';
import 'package:forgetmenot/widgets/app_state.dart';
import 'package:forgetmenot/widgets/common_widgets.dart';

class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({super.key});
  @override State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  List<dynamic> _visitors = [];
  bool _loading = true;
  Map<String, dynamic>? _recognitionResult;
  bool _recognizing = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final pid = context.read<AppState>().currentPatientId;
    if (pid == null) return;
    try {
      final data = await ApiService.getVisitors(pid);
      setState(() { _visitors = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _recognize() async {
    final pid = context.read<AppState>().currentPatientId;
    if (pid == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;

    setState(() { _recognizing = true; _recognitionResult = null; });
    try {
      final result = await ApiService.recognizeFace(pid, File(picked.path));
      setState(() => _recognitionResult = result);
    } catch (e) {
      setState(() => _recognitionResult = {'error': e.toString()});
    } finally {
      setState(() => _recognizing = false);
    }
  }

  void _showAddVisitor() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddVisitorSheet(
        patientId: context.read<AppState>().currentPatientId!,
        onCreated: (_) { Navigator.pop(context); _load(); },
      ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.surface,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Face Recognition'),
      elevation: 0,
      actions: [
        TextButton.icon(
          onPressed: _showAddVisitor,
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        // ── Recognize Banner ────────────────────────────────────────────
        GradientCard(
          gradient: AppTheme.greenGradient,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.face_retouching_natural_rounded,
                color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Identify a Visitor', style: TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Text('Point the camera at someone and ForgetMeNot will identify them.',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _recognizing ? null : _recognize,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.secondaryDark,
              ),
              icon: _recognizing
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      color: AppTheme.secondaryDark))
                : const Icon(Icons.camera_alt_rounded, size: 18),
              label: Text(_recognizing ? 'Identifying...' : 'Open Camera'),
            ),
          ]),
        ),

        // ── Recognition Result ──────────────────────────────────────────
        if (_recognitionResult != null) ...[
          const SizedBox(height: 16),
          _RecognitionResultCard(result: _recognitionResult!),
        ],

        const SizedBox(height: 24),
        SectionHeader(title: 'Registered Visitors (${_visitors.length})'),
        const SizedBox(height: 14),

        if (_loading) const LoadingWidget()
        else if (_visitors.isEmpty)
          EmptyStateWidget(
            icon: Icons.group_rounded,
            title: 'No Visitors Yet',
            subtitle: 'Add family and friends so the patient can recognize them',
            buttonLabel: '+ Add Visitor',
            onButton: _showAddVisitor,
          )
        else
          ..._visitors.map((v) => _VisitorCard(visitor: v, onDeleted: _load)),
      ]),
    ),
  );
}

class _RecognitionResultCard extends StatelessWidget {
  final Map result;
  const _RecognitionResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final recognized = result['recognized'] == true;
    final color = recognized ? AppTheme.success : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(
            recognized ? Icons.check_circle_rounded : Icons.help_outline_rounded,
            color: color, size: 26,
          )),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recognized
                ? '${result['visitor_name']} — ${result['relationship']}'
                : 'Unknown Visitor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
            ),
            Text(result['message'] ?? '',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMid)),
            if (recognized && result['confidence'] != null)
              Text('Confidence: ${(result['confidence'] * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        )),
      ]),
    );
  }
}

class _VisitorCard extends StatelessWidget {
  final Map visitor;
  final VoidCallback onDeleted;
  const _VisitorCard({required this.visitor, required this.onDeleted});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppTheme.softShadow,
    ),
    child: Row(children: [
      AvatarPlaceholder(name: visitor['name'] ?? '?', size: 48, color: AppTheme.secondary),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(visitor['name'] ?? '', style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          Text(visitor['relationship'] ?? '',
            style: const TextStyle(fontSize: 13, color: AppTheme.textMid)),
        ])),
      _UploadPhotoBtn(visitorId: visitor['visitor_id']),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () async {
          final ok = await showDialog<bool>(context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete Visitor'),
              content: Text('Remove ${visitor['name']}?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete', style: TextStyle(color: AppTheme.danger))),
              ],
            ));
          if (ok == true) {
            await ApiService.deleteVisitor(visitor['visitor_id']);
            onDeleted();
          }
        },
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 22),
      ),
    ]),
  );
}

class _UploadPhotoBtn extends StatefulWidget {
  final String visitorId;
  const _UploadPhotoBtn({required this.visitorId});
  @override State<_UploadPhotoBtn> createState() => _UploadPhotoBtnState();
}

class _UploadPhotoBtnState extends State<_UploadPhotoBtn> {
  bool _uploading = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      await ApiService.uploadVisitorPhoto(widget.visitorId, File(picked.path));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded!')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed')));
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _uploading ? null : _pick,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
      child: _uploading
        ? const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
        : const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_a_photo_rounded, size: 14, color: AppTheme.primary),
            SizedBox(width: 4),
            Text('Photo', style: TextStyle(
              fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ]),
    ),
  );
}

// ── Add Visitor Sheet ──────────────────────────────────────────────────────
class _AddVisitorSheet extends StatefulWidget {
  final String patientId;
  final Function(Map) onCreated;
  const _AddVisitorSheet({required this.patientId, required this.onCreated});
  @override State<_AddVisitorSheet> createState() => _AddVisitorSheetState();
}

class _AddVisitorSheetState extends State<_AddVisitorSheet> {
  final _nameCtrl = TextEditingController();
  String _relation = 'Family';
  bool _saving = false;
  static const _relations = ['Family', 'Spouse', 'Child', 'Sibling', 'Friend',
    'Caregiver', 'Doctor', 'Neighbor', 'Other'];

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final res = await ApiService.addVisitor(
        patientId: widget.patientId,
        name: _nameCtrl.text.trim(),
        relationship: _relation,
      );
      widget.onCreated(res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Add Visitor', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        IconButton(onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded)),
      ]),
      const SizedBox(height: 20),
      TextField(controller: _nameCtrl,
        decoration: const InputDecoration(labelText: 'Visitor Name',
          prefixIcon: Icon(Icons.person_rounded))),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _relation,
        items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
        onChanged: (v) => setState(() => _relation = v!),
        decoration: const InputDecoration(labelText: 'Relationship',
          prefixIcon: Icon(Icons.people_rounded)),
      ),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Register Visitor'),
        )),
    ]),
  );
}