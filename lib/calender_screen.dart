import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// monthKey -> {
  ///   "data": Map<DateTime, List<Event>>
  ///   "timestamp": DateTime (for cache freshness)
  /// }
  final Map<String, Map<String, dynamic>> _cache = {};

  Map<DateTime, List<Event>> _currentMonthEvents = {};


  @override
  void initState() {
    super.initState();
    _loadMonth(_focusedDay);
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _monthKey(DateTime d) => "${d.year}-${d.month}";

  // Future<void> addSampleEvents() async {
  //   final firestore = FirebaseFirestore.instance;

  //   await firestore.collection('events').add({
  //     'title': 'Team Meeting',
  //     'time': '10:00 AM',
  //     'date': Timestamp.fromDate(DateTime(2025, 12, 5)),
  //     'color': 'blue',
  //     'description': 'Monthly team sync',
  //   });

  //   await firestore.collection('events').add({
  //     'title': 'Client Presentation',
  //     'time': '2:00 PM',
  //     'date': Timestamp.fromDate(DateTime(2025, 12, 15)),
  //     'color': 'orange',
  //     'description': 'Q4 Review',
  //   });

  //   await firestore.collection('events').add({
  //     'title': 'Client Presentation',
  //     'time': '2:00 PM',
  //     'date': Timestamp.fromDate(DateTime(2026, 1, 15)),
  //     'color': 'orange',
  //     'description': 'Q4 Review',
  //   });

  //   await firestore.collection('events').add({
  //     'title': 'Client Presentation',
  //     'time': '2:00 PM',
  //     'date': Timestamp.fromDate(DateTime(2026, 1, 4)),
  //     'color': 'orange',
  //     'description': 'Q4 Review',
  //   });
  // }
  Future<void> _loadMonth(DateTime month) async {
    final key = _monthKey(month);

    // ---- CACHE CHECK ----
    if (_cache.containsKey(key)) {
      final timestamp = _cache[key]!["timestamp"] as DateTime;

      // Cache expires after 10 minutes
      if (DateTime.now().difference(timestamp).inMinutes < 10) {
        setState(() => _currentMonthEvents = _cache[key]!["data"]);
        return;
      }
    }

    // ---- FIRESTORE QUERY ----
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final query = await FirebaseFirestore.instance
        .collection("events")
        .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where("date", isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy("date")
        .get();

    final result = <DateTime, List<Event>>{};

    for (var doc in query.docs) {
      final data = doc.data();
      if (!data.containsKey("date")) continue;

      final ts = (data["date"] as Timestamp).toDate();
      final date = DateTime(ts.year, ts.month, ts.day);

      final event = Event(
        id: doc.id,
        title: data["title"] ?? "Untitled",
        time: data["time"] ?? "",
        color: _color(data["color"] ?? "blue"),
        description: data["description"] ?? "",
      );

      result.putIfAbsent(date, () => []);
      result[date]!.add(event);
    }

    // ---- UPDATE UI + CACHE ----
    setState(() => _currentMonthEvents = result);

    _cache[key] = {
      "data": result,
      "timestamp": DateTime.now(),
    };
  }

  Color _color(String name) {
    switch (name.toLowerCase()) {
      case "red":
        return Colors.red;
      case "green":
        return Colors.green;
      case "orange":
        return Colors.orange;
      case "purple":
        return Colors.purple;
      case "pink":
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  List<Event> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _currentMonthEvents[key] ?? [];
  }

  void _onPageChanged(DateTime focused) {
    _focusedDay = focused;
    _loadMonth(focused);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Loading ${DateFormat('MMMM yyyy').format(focused)}"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onDaySelected(DateTime selected, DateTime focused) {
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });

    final events = _eventsForDay(selected);

    if (events.isEmpty) {
      _noEvents(selected);
    } else {
      _showEvents(selected, events);
    }
  }

  void _noEvents(DateTime day) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.event_busy, size: 40, color: Colors.orange),
        title: const Text("No Events"),
        content: Text(
          "No events on ${DateFormat('MMMM d, yyyy').format(day)}",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  void _showEvents(DateTime day, List<Event> events) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(DateFormat('MMMM d, yyyy').format(day)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: events.length,
            itemBuilder: (_, i) {
              final e = events[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: e.color),
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${e.time}\n${e.description}"),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Firebase Calendar"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _cache.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Cache Cleared")),
              );
              _loadMonth(_focusedDay);
            },
          )
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            eventLoader: _eventsForDay,
            onDaySelected: _onDaySelected,
            onPageChanged: _onPageChanged,
            onFormatChanged: (f) => setState(() => _calendarFormat = f),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(.4),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
                markersMaxCount: 1,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              formatButtonShowsNext: false,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      width: 7,
                      height: 7,
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          // Instructions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.cloud_done, color: Colors.blue, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Connected to Firebase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Swipe to load events for different months',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    // ElevatedButton(onPressed: (){
                    //   addSampleEvents();
                    // }, child: Text("Add."))
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Event {
  final String id, title, time, description;
  final Color color;
  Event({required this.id, required this.title, required this.time, required this.color, required this.description});
}
