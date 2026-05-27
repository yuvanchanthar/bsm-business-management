import 'package:shared_preferences/shared_preferences.dart';

class SmsSettingsService {
  static const String _kSmsMode = 'sms_mode';
  static const String _kSimIndex = 'sim_index';

  static final SmsSettingsService _instance = SmsSettingsService._internal();
  factory SmsSettingsService() => _instance;
  SmsSettingsService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get smsMode => _prefs.getString(_kSmsMode) ?? 'my_number';
  int get simIndex => _prefs.getInt(_kSimIndex) ?? 0; // 0: Default, 1: SIM 1, 2: SIM 2

  Future<void> setSmsMode(String mode) async {
    await _prefs.setString(_kSmsMode, mode);
  }

  Future<void> setSimIndex(int index) async {
    await _prefs.setInt(_kSimIndex, index);
  }

  Future<void> saveSettings({required String mode, required int simIndex}) async {
    await _prefs.setString(_kSmsMode, mode);
    await _prefs.setInt(_kSimIndex, simIndex);
  }
}
