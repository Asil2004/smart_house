import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/mqtt_service.dart';
import 'services/settings_service.dart';
import 'services/smart_voice_service.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => MqttService()..connect()),
        ChangeNotifierProxyProvider2<MqttService, SettingsService, SmartVoiceService>(
          create: (ctx) => SmartVoiceService(
            mqttService: Provider.of<MqttService>(ctx, listen: false),
            settingsService: Provider.of<SettingsService>(ctx, listen: false),
          ),
          update: (ctx, mqtt, settings, voice) =>
              voice ?? SmartVoiceService(mqttService: mqtt, settingsService: settings),
        ),
      ],
      child: const SmartHouseApp(),
    ),
  );
}

class SmartHouseApp extends StatelessWidget {
  const SmartHouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aqlli Uy - Ovozli Tizim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mqtt = context.watch<MqttService>();
    final settings = context.watch<SettingsService>();
    final voice = context.watch<SmartVoiceService>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.home_filled, color: Color(0xFF6366F1), size: 28),
            const SizedBox(width: 8),
            Text(
              'Aqlli Uy (${settings.agentName})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          // Sozlamalar tugmasi (API Key, Agent nomi, Ovoz ajratish)
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: "Tizim sozlamalari",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          // MQTT holat nishoni
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: mqtt.isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mqtt.isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: mqtt.isConnected ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  mqtt.isConnected ? 'Tarmoqda' : 'Aloqada emas',
                  style: TextStyle(
                    fontSize: 12,
                    color: mqtt.isConnected ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agar API Key kiritilmagan bo'lsa ogohlantiruvchi bildirishnoma
            if (!settings.isConfigured)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amberAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Dastlabki sozlash: API Key va Agent nomini kiritish uchun Sozlamalarga kiring.",
                        style: TextStyle(fontSize: 13, color: Colors.amber[100]),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      child: const Text("Kiritish", style: TextStyle(color: Colors.amberAccent)),
                    ),
                  ],
                ),
              ),

            // Ovozli Agent holat paneli
            _buildVoiceFeedbackCard(voice, settings),
            const SizedBox(height: 20),

            // Datchiklar paneli (Harorat, Namlik, Gaz, Harakat)
            const Text(
              "Uy Muhiti & Sensorlar",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            _buildSensorsGrid(mqtt),

            const SizedBox(height: 24),
            // Qurilmalarni qo'lda boshqarish
            const Text(
              "Boshqaruv Paneli",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            _buildAppliancesGrid(mqtt),
            const SizedBox(height: 85),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: voice.isListening ? Colors.redAccent : const Color(0xFF6366F1),
        elevation: 10,
        onPressed: () => voice.toggleListening(),
        icon: Icon(
          voice.isListening ? Icons.mic : Icons.mic_none,
          color: Colors.white,
          size: 28,
        ),
        label: Text(
          voice.isListening
              ? "Tinglamoqda..."
              : "${settings.agentName} Ovoz",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildVoiceFeedbackCard(SmartVoiceService voice, SettingsService settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "${settings.agentName} AI Agenti",
                    style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: settings.wakeWordRequired ? Colors.blue.withOpacity(0.2) : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  settings.wakeWordRequired ? "Ovoz ajratish faol" : "To'g'ridan-to'g'ri rejim",
                  style: TextStyle(
                    fontSize: 11,
                    color: settings.wakeWordRequired ? Colors.lightBlueAccent : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            voice.isListening
                ? (voice.recognizedText.isEmpty ? "Eshitilmoqda..." : "\"${voice.recognizedText}\"")
                : voice.lastResponse,
            style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.3),
          ),
          if (voice.separatedCommand.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Ajratilgan buyruq: '${voice.separatedCommand}'",
              style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorsGrid(MqttService mqtt) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _buildSensorCard(
          "Harorat",
          "${mqtt.temperature.toStringAsFixed(1)} °C",
          Icons.thermostat,
          Colors.orangeAccent,
        ),
        _buildSensorCard(
          "Namlik",
          "${mqtt.humidity.toStringAsFixed(0)} %",
          Icons.water_drop,
          Colors.blueAccent,
        ),
        _buildSensorCard(
          "Gaz / Tutun",
          mqtt.gasLevel > 1500 ? "XAVF!" : "Xavfsiz",
          Icons.air,
          mqtt.gasLevel > 1500 ? Colors.redAccent : Colors.tealAccent,
        ),
        _buildSensorCard(
          "Harakat",
          mqtt.motionDetected ? "Aniqlondi" : "Tinch",
          Icons.directions_walk,
          mqtt.motionDetected ? Colors.amberAccent : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, color: Colors.white60)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAppliancesGrid(MqttService mqtt) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: [
        _buildControlCard(
          "Mehmonxona",
          mqtt.livingRoom,
          Icons.lightbulb,
          (val) => mqtt.sendCommand(val ? "ON" : "OFF", "living_room"),
        ),
        _buildControlCard(
          "Oshxona",
          mqtt.kitchen,
          Icons.soup_kitchen,
          (val) => mqtt.sendCommand(val ? "ON" : "OFF", "kitchen"),
        ),
        _buildControlCard(
          "Yotoqxona",
          mqtt.bedroom,
          Icons.bed,
          (val) => mqtt.sendCommand(val ? "ON" : "OFF", "bedroom"),
        ),
        _buildControlCard(
          "Ventilyator",
          mqtt.fan,
          Icons.mode_fan_off,
          (val) => mqtt.sendCommand(val ? "ON" : "OFF", "fan"),
        ),
        _buildControlCard(
          "Eshik Qulfi",
          !mqtt.doorLocked,
          Icons.door_front_door,
          (val) => mqtt.sendCommand(val ? "OPEN" : "CLOSE", "door"),
          activeText: "Ochiq",
          inactiveText: "Qulflangan",
        ),
        _buildControlCard(
          "Xavfsizlik",
          mqtt.securityActive,
          Icons.shield,
          (val) => mqtt.sendCommand(val ? "ON" : "OFF", "security"),
          activeText: "Faol",
          inactiveText: "O'chiq",
        ),
      ],
    );
  }

  Widget _buildControlCard(
    String title,
    bool isActive,
    IconData icon,
    Function(bool) onToggle, {
    String activeText = "Yoniq",
    String inactiveText = "O'chiq",
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF312E81) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF6366F1) : Colors.white12,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.amberAccent : Colors.white54,
                size: 28,
              ),
              Switch(
                value: isActive,
                activeColor: const Color(0xFF6366F1),
                onChanged: onToggle,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                isActive ? activeText : inactiveText,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.greenAccent : Colors.white38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
