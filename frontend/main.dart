import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

// TODO: sostituisci con il tuo dominio reale una volta online su PythonAnywhere
const String baseUrl = "https://frafalone.pythonanywhere.com";
const String appVersion = "1.0.0";

void main() {
  runApp(const MacroCalendarApp());
}

class MacroCalendarApp extends StatelessWidget {
  const MacroCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Macro Calendar',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class MacroEvent {
  final String name;
  final String importance;
  final List<String> currencies;
  final String date;
  final String? time;

  MacroEvent({
    required this.name,
    required this.importance,
    required this.currencies,
    required this.date,
    required this.time,
  });

  factory MacroEvent.fromJson(Map<String, dynamic> json) {
    return MacroEvent(
      name: json['name'],
      importance: json['importance'],
      currencies: List<String>.from(json['currencies']),
      date: json['date'],
      time: json['time'],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MacroEvent> events = [];
  bool loading = true;
  bool notificationsEnabled = false;
  bool calendarEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _checkPermissions();
  }

  Future<void> _loadEvents() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/events/upcoming'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          events = data.map((e) => MacroEvent.fromJson(e)).toList();
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _checkPermissions() async {
    final notifStatus = await Permission.notification.status;
    final calStatus = await Permission.calendarFullAccess.status;
    setState(() {
      notificationsEnabled = notifStatus.isGranted;
      calendarEnabled = calStatus.isGranted;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      setState(() => notificationsEnabled = status.isGranted);
    } else {
      setState(() => notificationsEnabled = false);
    }
  }

  Future<void> _toggleCalendar(bool value) async {
    if (value) {
      final status = await Permission.calendarFullAccess.request();
      setState(() => calendarEnabled = status.isGranted);
    } else {
      setState(() => calendarEnabled = false);
    }
  }

  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Versione'),
        content: Text('Macro Calendar v$appVersion'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showCreditsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crediti'),
        content: const Text('Sviluppato da Francesco Falone.\nDati: ECB, BLS, Eurostat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Macro Calendar')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notizie imminenti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : events.isEmpty
                  ? const Center(child: Text('Nessuna notizia imminente'))
                  : ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final e = events[index];
                  return Card(
                    child: ListTile(
                      title: Text(e.name),
                      subtitle: Text(
                        '${e.date}${e.time != null ? " - ${e.time}" : ""} · ${e.currencies.join(",")} · ${e.importance}',
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notifiche'),
                Switch(value: notificationsEnabled, onChanged: _toggleNotifications),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Accesso calendario'),
                Switch(value: calendarEnabled, onChanged: _toggleCalendar),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(onPressed: _showVersionDialog, child: const Text('Versione')),
                OutlinedButton(onPressed: _showCreditsDialog, child: const Text('Crediti')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
