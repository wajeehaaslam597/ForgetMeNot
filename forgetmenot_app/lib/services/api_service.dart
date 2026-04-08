import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiService {
  /// Resolved from [ApiConfig] (emulator vs device vs `--dart-define=API_BASE=...`).
  static String get baseUrl => ApiConfig.baseUrl;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Patients ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createPatient({
    required String name,
    int? age,
    String? relationship,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/patients'),
      headers: _headers,
      body: jsonEncode({'name': name, 'age': age, 'relationship': relationship}),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> listPatients() async {
    final res = await http.get(Uri.parse('$baseUrl/patients'), headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPatient(String patientId) async {
    final res = await http.get(Uri.parse('$baseUrl/patients/$patientId'), headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updatePatient(
    String patientId, {
    required String name,
    int? age,
    String? relationship,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/patients/$patientId'),
      headers: _headers,
      body: jsonEncode({'name': name, 'age': age, 'relationship': relationship}),
    );
    return jsonDecode(res.body);
  }

  static Future<void> deletePatient(String patientId) async {
    await http.delete(Uri.parse('$baseUrl/patients/$patientId'), headers: _headers);
  }

  static Future<Map<String, dynamic>> uploadPatientPhoto(
    String patientId, File photo,
  ) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/patients/$patientId/photo'));
    req.files.add(await http.MultipartFile.fromPath('file', photo.path));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return jsonDecode(res.body);
  }

  // ── Reminders ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createReminder({
    required String patientId,
    required String title,
    required String reminderType,
    required String scheduledTime,
    String repeatOption = 'one-time',
    String? voiceMessage,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/reminders'),
      headers: _headers,
      body: jsonEncode({
        'patient_id':    patientId,
        'title':         title,
        'reminder_type': reminderType,
        'scheduled_time':scheduledTime,
        'repeat_option': repeatOption,
        'voice_message': voiceMessage,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getReminders(String patientId, {String? date}) async {
    String url = '$baseUrl/reminders/$patientId';
    if (date != null) url += '?date=$date';
    final res = await http.get(Uri.parse(url), headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getTodayReminders(String patientId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/reminders/$patientId/today'), headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateReminderStatus(
    String reminderId, String status,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/reminders/$reminderId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return jsonDecode(res.body);
  }

  static Future<void> deleteReminder(String reminderId) async {
    await http.delete(Uri.parse('$baseUrl/reminders/$reminderId'), headers: _headers);
  }

  // ── Visitors ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addVisitor({
    required String patientId,
    required String name,
    required String relationship,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/visitors'),
      headers: _headers,
      body: jsonEncode({'patient_id': patientId, 'name': name, 'relationship': relationship}),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getVisitors(String patientId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/visitors/$patientId'), headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> uploadVisitorPhoto(
    String visitorId, File photo,
  ) async {
    final req = http.MultipartRequest(
      'POST', Uri.parse('$baseUrl/visitors/$visitorId/photos'),
    );
    req.files.add(await http.MultipartFile.fromPath('file', photo.path));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> recognizeFace(
    String patientId, File photo,
  ) async {
    final req = http.MultipartRequest(
      'POST', Uri.parse('$baseUrl/face/recognize/$patientId'),
    );
    req.files.add(await http.MultipartFile.fromPath('file', photo.path));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return jsonDecode(res.body);
  }

  static Future<void> deleteVisitor(String visitorId) async {
    await http.delete(Uri.parse('$baseUrl/visitors/$visitorId'), headers: _headers);
  }

  // ── Voice / TTS ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> voiceCommandResponse({
    required String command,
    required String patientId,
    String language = 'en',
  }) async {
    final req = http.MultipartRequest(
      'POST', Uri.parse('$baseUrl/voice/recognize-response'),
    );
    req.fields['command']    = command;
    req.fields['patient_id'] = patientId;
    req.fields['language']   = language;
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return jsonDecode(res.body);
  }

  static String ttsUrl(String text, {String language = 'en'}) {
    return '$baseUrl/voice/tts';
  }

  static String audioUrl(String filename) => '$baseUrl/audio/$filename';

  // ── Dashboard ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard(String patientId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/dashboard/$patientId'), headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getAllPatientsSummary() async {
    final res = await http.get(
      Uri.parse('$baseUrl/dashboard/all/patients'), headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Logs ─────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getLogs(
    String patientId, {String? date, String? eventType}
  ) async {
    String url = '$baseUrl/logs/$patientId';
    final params = <String>[];
    if (date != null) params.add('date=$date');
    if (eventType != null) params.add('event_type=$eventType');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getLogSummary(String patientId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/logs/$patientId/summary'), headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ── Settings ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSettings(String patientId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/settings/$patientId'), headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateSettings(
    String patientId, {
    String language = 'en',
    bool autoRecognition = true,
    int cooldown = 60,
    int snoozeMins = 5,
  }) async {
    final req = http.MultipartRequest(
      'PUT', Uri.parse('$baseUrl/settings/$patientId'),
    );
    req.fields['language']                     = language;
    req.fields['auto_recognition']             = autoRecognition.toString();
    req.fields['recognition_cooldown_seconds'] = cooldown.toString();
    req.fields['reminder_snooze_minutes']       = snoozeMins.toString();
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return jsonDecode(res.body);
  }
}