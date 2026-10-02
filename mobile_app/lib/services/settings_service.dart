import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  String apiKey = '';
  String agentName = 'Yordamchi';
  String apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta';
  String esp32Ip = '192.168.1.100';
  bool useLocalWifi = false;
  bool wakeWordRequired = false;
  bool shortAnswers = true;        // Qisqa tezkor javoblar (Yoqdim, Tayyor, Ochdim)
  bool continuousChat = false;     // Uzluksiz muloqot rejimi (Avtomatik yana tinglash)

  SettingsService() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    apiKey = prefs.getString('api_key') ?? apiKey;
    agentName = prefs.getString('agent_name') ?? 'Yordamchi';
    apiEndpoint = prefs.getString('api_endpoint') ?? 'https://generativelanguage.googleapis.com/v1beta';
    esp32Ip = prefs.getString('esp32_ip') ?? '192.168.1.100';
    useLocalWifi = prefs.getBool('use_local_wifi') ?? false;
    wakeWordRequired = prefs.getBool('wake_word_required') ?? true;
    shortAnswers = prefs.getBool('short_answers') ?? true;
    continuousChat = prefs.getBool('continuous_chat') ?? false;
    notifyListeners();
  }

  Future<void> toggleContinuousChat() async {
    continuousChat = !continuousChat;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('continuous_chat', continuousChat);
    notifyListeners();
  }

  Future<void> saveSettings({
    required String newApiKey,
    required String newAgentName,
    required String newApiEndpoint,
    required String newEsp32Ip,
    required bool newUseLocalWifi,
    required bool newWakeWordRequired,
    required bool newShortAnswers,
    required bool newContinuousChat,
  }) async {
    apiKey = newApiKey;
    agentName = newAgentName.trim().isEmpty ? 'Yordamchi' : newAgentName.trim();
    apiEndpoint = newApiEndpoint;
    esp32Ip = newEsp32Ip;
    useLocalWifi = newUseLocalWifi;
    wakeWordRequired = newWakeWordRequired;
    shortAnswers = newShortAnswers;
    continuousChat = newContinuousChat;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', apiKey);
    await prefs.setString('agent_name', agentName);
    await prefs.setString('api_endpoint', apiEndpoint);
    await prefs.setString('esp32_ip', esp32Ip);
    await prefs.setBool('use_local_wifi', useLocalWifi);
    await prefs.setBool('wake_word_required', wakeWordRequired);
    await prefs.setBool('short_answers', shortAnswers);
    await prefs.setBool('continuous_chat', continuousChat);

    notifyListeners();
  }

  bool get isConfigured => apiKey.isNotEmpty;
}
