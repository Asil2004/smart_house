import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _agentNameCtrl;
  late TextEditingController _apiEndpointCtrl;
  late TextEditingController _esp32IpCtrl;

  bool _obscureApiKey = true;
  bool _useLocalWifi = false;
  bool _wakeWordRequired = true;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsService>(context, listen: false);
    _apiKeyCtrl = TextEditingController(text: settings.apiKey);
    _agentNameCtrl = TextEditingController(text: settings.agentName);
    _apiEndpointCtrl = TextEditingController(text: settings.apiEndpoint);
    _esp32IpCtrl = TextEditingController(text: settings.esp32Ip);
    _useLocalWifi = settings.useLocalWifi;
    _wakeWordRequired = settings.wakeWordRequired;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _agentNameCtrl.dispose();
    _apiEndpointCtrl.dispose();
    _esp32IpCtrl.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await Provider.of<SettingsService>(context, listen: false).saveSettings(
        newApiKey: _apiKeyCtrl.text.trim(),
        newAgentName: _agentNameCtrl.text.trim(),
        newApiEndpoint: _apiEndpointCtrl.text.trim(),
        newEsp32Ip: _esp32IpCtrl.text.trim(),
        newUseLocalWifi: _useLocalWifi,
        newWakeWordRequired: _wakeWordRequired,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sozlamalar muvaffaqiyatli saqlandi!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Tizim Sozlamalari"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "🤖 Ovozli Agent & API Sozlamalari",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF818CF8),
                ),
              ),
              const SizedBox(height: 16),

              // Agent Nomi
              TextFormField(
                controller: _agentNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Agent Nomi",
                  hintText: "Masalan: Yordamchi",
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF818CF8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Agent nomini kiriting";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // API Key
              TextFormField(
                controller: _apiKeyCtrl,
                obscureText: _obscureApiKey,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Agent API Key",
                  hintText: "Maxfiy API kalitingizni kiriting",
                  prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF818CF8)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white60,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // API Endpoint URL
              TextFormField(
                controller: _apiEndpointCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "API Server URL",
                  hintText: "https://generativelanguage.googleapis.com/v1beta",
                  prefixIcon: const Icon(Icons.cloud, color: Color(0xFF818CF8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                "🎙️ Ovozni Ajratish Funksiyasi",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF818CF8),
                ),
              ),
              const SizedBox(height: 12),

              // Ovozni ajratish / Wake word switch
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text(
                    "Faqat Agent nomiga javob berish (Ovozni ajratish)",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _wakeWordRequired
                        ? "Shovqin va boshqa suhbatlar filtrlanadi. Buyruq '${_agentNameCtrl.text}' bilan boshlanganda ishlaydi."
                        : "Har qanday gapirilgan gap to'g'ridan-to'g'ri buyruq sifatida qabul qilinadi.",
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  value: _wakeWordRequired,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (val) {
                    setState(() {
                      _wakeWordRequired = val;
                    });
                  },
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                "📡 ESP32 & Tarmoq Sozlamalari",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF818CF8),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text(
                    "Mahalliy Wi-Fi orqali boshqarish",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "Internet shart emas, ESP32 va telefon bir Wi-Fi ga ulangan bo'lishi kifoya.",
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  value: _useLocalWifi,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (val) {
                    setState(() {
                      _useLocalWifi = val;
                    });
                  },
                ),
              ),

              if (_useLocalWifi) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _esp32IpCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "ESP32 IP Manzili",
                    hintText: "192.168.1.100",
                    prefixIcon: const Icon(Icons.router, color: Color(0xFF818CF8)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 36),
              // Saqlash tugmasi
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text(
                    "Sozlamalarni Saqlash",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
