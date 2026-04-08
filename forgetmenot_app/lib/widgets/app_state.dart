import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  String? _currentPatientId;
  String? _currentPatientName;
  bool    _isCaregiver = true;

  String? get currentPatientId   => _currentPatientId;
  String? get currentPatientName => _currentPatientName;
  bool    get isCaregiver        => _isCaregiver;
  bool    get hasPatient         => _currentPatientId != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currentPatientId   = prefs.getString('patient_id');
    _currentPatientName = prefs.getString('patient_name');
    _isCaregiver        = prefs.getBool('is_caregiver') ?? true;
    notifyListeners();
  }

  Future<void> setPatient(String id, String name) async {
    _currentPatientId   = id;
    _currentPatientName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('patient_id', id);
    await prefs.setString('patient_name', name);
    notifyListeners();
  }

  Future<void> setMode(bool caregiver) async {
    _isCaregiver = caregiver;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_caregiver', caregiver);
    notifyListeners();
  }

  Future<void> clear() async {
    _currentPatientId   = null;
    _currentPatientName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}