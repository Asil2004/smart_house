import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'mqtt_service.dart';
import 'settings_service.dart';

class SmartVoiceService extends ChangeNotifier {
  final MqttService mqttService;
  final SettingsService settingsService;
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool isListening = false;
  String recognizedText = "";
  String separatedCommand = "";
  String lastResponse = "Ovozli yordamchi tayyor...";
  bool isProcessing = false;

  SmartVoiceService({
    required this.mqttService,
    required this.settingsService,
  }) {
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("uz-UZ");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> speak(String text) async {
    lastResponse = text;
    notifyListeners();
    await _tts.speak(text);
  }

  /// Ovozni tinglashni boshlash/to'xtatish
  Future<void> toggleListening() async {
    if (isListening) {
      await _speech.stop();
      isListening = false;
      notifyListeners();
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint("STT Status: $status");
          if (status == 'done' || status == 'notListening') {
            isListening = false;
            notifyListeners();
          }
        },
        onError: (errorNotification) {
          debugPrint("STT Xatolik: $errorNotification");
          isListening = false;
          notifyListeners();
        },
      );

      if (available) {
        isListening = true;
        recognizedText = "";
        separatedCommand = "";
        notifyListeners();

        _speech.listen(
          localeId: 'uz_UZ',
          listenMode: stt.ListenMode.confirmation,
          onResult: (result) {
            recognizedText = result.recognizedWords;
            notifyListeners();
            if (result.finalResult) {
              _processSpokenAudio(recognizedText);
            }
          },
        );
      } else {
        speak("Mikrofonni ishga tushirib bo'lmadi. Sozlamalardan ruxsatlarni tekshiring.");
      }
    }
  }

  Future<void> _processSpokenAudio(String rawSpeech) async {
    String cleanSpeech = rawSpeech.toLowerCase().trim();
    debugPrint("[Eshitildi]: $cleanSpeech");

    if (cleanSpeech.isEmpty) return;

    separatedCommand = cleanSpeech.replaceAll(RegExp(r'[,.!?]'), '').trim();
    debugPrint("[Buyruq]: $separatedCommand");

    if (separatedCommand.isEmpty) {
      speak("Eshityapman, qanday yordam bera olaman?");
      return;
    }

    isProcessing = true;
    notifyListeners();

    // 1. Gemini / Cloud AI orqali tahlil qilish
    if (settingsService.apiKey.isNotEmpty) {
      bool handledByApi = await _sendToGeminiApi(separatedCommand);
      if (handledByApi) {
        isProcessing = false;
        notifyListeners();
        return;
      }
    }

    // 2. Agar internet yoki API bo'lmasa, mahalliy O'zbekcha qoidalar bilan ijro etish
    _executeLocalUzbekIntent(separatedCommand);
    isProcessing = false;
    notifyListeners();
  }

  /// Google Gemini API orqali muloqot va uy boshqaruvi
  Future<bool> _sendToGeminiApi(String commandText) async {
    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=${settingsService.apiKey}"
      );

      final prompt = """Sen zamonaviy aqlli uyning zukko, do'stona sun'iy intellekt yordamchisisan.
Qat'iy ravishda quyidagi JSON formatida javob ber:
{
  "reply": "O'zbek tilidagi qisqa, samimiy javobing",
  "action": "ON | OFF | OPEN | CLOSE | NONE",
  "target": "living_room | kitchen | bedroom | fan | door | all_lights | NONE"
}
Foydalanuvchi: $commandText""";

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'role': 'user',
            'parts': [{'text': prompt}]
          }],
          'generationConfig': {'responseMimeType': 'application/json'}
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final rawJson = resData['candidates'][0]['content']['parts'][0]['text'];
        final parsed = jsonDecode(rawJson);

        String action = parsed['action'] ?? '';
        String target = parsed['target'] ?? '';
        String voiceAnswer = parsed['reply'] ?? 'Bajarildi';

        if (action.isNotEmpty && target.isNotEmpty && target != "NONE") {
          mqttService.sendCommand(action, target);
        }
        await speak(voiceAnswer);
        return true;
      }
    } catch (e) {
      debugPrint("Gemini API xatosi: $e (Mahalliy tahlilga o'tilmoqda)");
    }
    return false;
  }

  /// Mahalliy O'zbekcha niyatlarni aniqlash (Offline NLU Fallback)
  void _executeLocalUzbekIntent(String text) {
    if (text.contains("hamma chiroq") || text.contains("barcha chiroq")) {
      if (text.contains("yoq") || text.contains("yonsin")) {
        mqttService.sendCommand("ON", "all_lights");
        speak("Barcha chiroqlarni yoqdim.");
      } else if (text.contains("o'chir") || text.contains("ochir") || text.contains("o'chsin")) {
        mqttService.sendCommand("OFF", "all_lights");
        speak("Barcha chiroqlarni o'chirdim.");
      }
    } 
    else if (text.contains("mehmonxona") || text.contains("zal")) {
      if (text.contains("yoq") || text.contains("yonsin")) {
        mqttService.sendCommand("ON", "living_room");
        speak("Mehmonxona chirog'i yoqildi.");
      } else if (text.contains("o'chir") || text.contains("ochir")) {
        mqttService.sendCommand("OFF", "living_room");
        speak("Mehmonxona chirog'i o'chirildi.");
      }
    }
    else if (text.contains("oshxona")) {
      if (text.contains("yoq") || text.contains("yonsin")) {
        mqttService.sendCommand("ON", "kitchen");
        speak("Oshxona chirog'ini yoqdim.");
      } else if (text.contains("o'chir") || text.contains("ochir")) {
        mqttService.sendCommand("OFF", "kitchen");
        speak("Oshxona chirog'i o'chirildi.");
      }
    }
    else if (text.contains("yotoqxona") || text.contains("spalni")) {
      if (text.contains("yoq") || text.contains("yonsin")) {
        mqttService.sendCommand("ON", "bedroom");
        speak("Yotoqxona chirog'ini yoqdim.");
      } else if (text.contains("o'chir") || text.contains("ochir")) {
        mqttService.sendCommand("OFF", "bedroom");
        speak("Yotoqxona chirog'i o'chirildi.");
      }
    }
    else if (text.contains("ventilyator") || text.contains("konditsioner") || text.contains("parrak")) {
      if (text.contains("yoq") || text.contains("ishlasin")) {
        mqttService.sendCommand("ON", "fan");
        speak("Ventilyator yoqildi.");
      } else if (text.contains("o'chir") || text.contains("to'xtat")) {
        mqttService.sendCommand("OFF", "fan");
        speak("Ventilyator to'xtatildi.");
      }
    }
    else if (text.contains("eshik")) {
      if (text.contains("och") || text.contains("ochilsin")) {
        mqttService.sendCommand("OPEN", "door");
        speak("Eshik ochildi.");
      } else if (text.contains("qulfla") || text.contains("yop") || text.contains("bekit")) {
        mqttService.sendCommand("CLOSE", "door");
        speak("Eshik xavfsiz qulflandi.");
      }
    }
    else if (text.contains("harorat") || text.contains("gradus") || text.contains("havo")) {
      speak("Hozir xonada harorat ${mqttService.temperature.toStringAsFixed(1)} gradus, namlik ${mqttService.humidity.toStringAsFixed(0)} foiz.");
    }
    else if (text.contains("gaz") || text.contains("xavf") || text.contains("tutun")) {
      if (mqttService.gasLevel > 1500) {
        speak("Diqqat, xonada gaz sizib chiqishi aniqlandi!");
      } else {
        speak("Xonada gaz yo'q, xavfsizlik joyida.");
      }
    }
    else if (text.contains("salom") || text.contains("assalomu")) {
      speak("Assalomu alaykum! Men aqlli uy yordamchingizman. Qanday yordam bera olaman?");
    }
    else {
      speak("Sizni eshitdim. Buyrug'ingizni bajaryapman.");
    }
  }
}
