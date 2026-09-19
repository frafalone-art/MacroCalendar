import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:device_calendar/device_calendar.dart';

const String appVersion = "1.0.0";
const String backendUrlPrefKey = "backend_url";

// Quanto preavviso dare prima di un evento (minuti)
const int notificationLeadMinutes = 15;

final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
final DeviceCalendarPlugin deviceCalendarPlugin = DeviceCalendarPlugin();

Future<void> initNotifications() async {
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Rome'));

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
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

  DateTime? get dateTime {
    if (time == null) return null;
    try {
      final dateParts = date.split('-').map(int.parse).toList();
      final timeParts = time!.split(':').map(int.parse).toList();
      return DateTime(dateParts[0], dateParts[1], dateParts[2], timeParts[0], timeParts[1]);
    } catch (_) {
      return null;
    }
  }

  bool get isSpecial => name.toLowerCase().contains('press conference');
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
  String? backendUrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(backendUrlPrefKey);

    if (savedUrl == null || savedUrl.isEmpty) {
      setState(() => loading = false);
      // Chiede l'URL al primo avvio, dopo il primo frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _showBackendUrlDialog(firstSetup: true));
      return;
    }

    setState(() => backendUrl = savedUrl);
    await _checkPermissions();
    await _loadEvents();
  }

  Future<void> _saveBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(backendUrlPrefKey, url);
    setState(() => backendUrl = url);
    await _loadEvents();
  }

  void _showBackendUrlDialog({bool firstSetup = false}) {
    final controller = TextEditingController(text: backendUrl ?? '');
    showDialog(
      context: context,
      barrierDismissible: !firstSetup,
      builder: (_) => AlertDialog(
        title: const Text('Backend URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (firstSetup)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'This app needs your own backend deployment. See the project README for setup instructions.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'https://your-backend.example.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                _saveBackendUrl(url.endsWith('/') ? url.substring(0, url.length - 1) : url);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadEvents() async {
    if (backendUrl == null) return;
    setState(() => loading = true);
    try {
      final response = await http
          .get(Uri.parse('$backendUrl/events/upcoming'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final loadedEvents = data.map((e) => MacroEvent.fromJson(e)).toList();
        setState(() {
          events = loadedEvents;
          loading = false;
        });

        if (notificationsEnabled) await _scheduleNotifications(loadedEvents);
        if (calendarEnabled) await _addSpecialEventsToCalendar(loadedEvents);
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
      if (status.isGranted) await _scheduleNotifications(events);
    } else {
      setState(() => notificationsEnabled = false);
      await notificationsPlugin.cancelAll();
    }
  }

  Future<void> _toggleCalendar(bool value) async {
    if (value) {
      final status = await Permission.calendarFullAccess.request();
      setState(() => calendarEnabled = status.isGranted);
      if (status.isGranted) await _addSpecialEventsToCalendar(events);
    } else {
      setState(() => calendarEnabled = false);
    }
  }

  Future<void> _scheduleNotifications(List<MacroEvent> events) async {
    const androidDetails = AndroidNotificationDetails(
      'macro_events',
      'Eventi macroeconomici',
      channelDescription: 'Notifiche per eventi macro imminenti',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    for (final event in events) {
      final eventDateTime = event.dateTime;
      if (eventDateTime == null) continue;

      final notifyAt = eventDateTime.subtract(const Duration(minutes: notificationLeadMinutes));
      if (notifyAt.isBefore(DateTime.now())) continue;

      final id = event.name.hashCode ^ event.date.hashCode;

      await notificationsPlugin.zonedSchedule(
        id,
        event.name,
        'Tra $notificationLeadMinutes minuti (${event.currencies.join(",")})',
        tz.TZDateTime.from(notifyAt, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _addSpecialEventsToCalendar(List<MacroEvent> events) async {
    final permissionResult = await deviceCalendarPlugin.hasPermissions();
    if (permissionResult.data != true) {
      final requestResult = await deviceCalendarPlugin.requestPermissions();
      if (requestResult.data != true) return;
    }

    final calendarsResult = await deviceCalendarPlugin.retrieveCalendars();
    final writableCalendars = calendarsResult.data?.where((c) => c.isReadOnly == false).toList() ?? [];
    if (writableCalendars.isEmpty) return;

    final targetCalendar = writableCalendars.first;

    for (final event in events.where((e) => e.isSpecial)) {
      final startTime = event.dateTime;
      if (startTime == null) continue;

      final calendarEvent = Event(
        targetCalendar.id,
        title: event.name,
        start: tz.TZDateTime.from(startTime, tz.local),
        end: tz.TZDateTime.from(startTime.add(const Duration(hours: 1)), tz.local),
      );

      await deviceCalendarPlugin.createOrUpdateEvent(calendarEvent);
    }
  }

  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Versione'),
        content: Text('Macro Calendar v$appVersion'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showCreditsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crediti'),
        content: const Text('Sviluppato da Francesco Falone.\nDati: ECB, BLS, Eurostat.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Macro Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showBackendUrlDialog(),
          ),
        ],
      ),
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
                  : backendUrl == null
                      ? const Center(child: Text('Configura il backend dalle impostazioni ⚙️'))
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
                                    trailing: e.isSpecial ? const Icon(Icons.star, color: Colors.amber) : null,
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
