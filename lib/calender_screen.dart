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

  // Cache for storing events by month to avoid repeated queries
  final Map<String, Map<DateTime, List<Event>>> _monthlyEventsCache = {};

  // Current month's events
  Map<DateTime, List<Event>> _currentMonthEvents = {};

  // Stream subscription for real-time updates
  Stream<QuerySnapshot>? _eventsStream;

  @override
  void initState() {
    super.initState();
    _loadEventsForMonth(_focusedDay);
    // addSampleEvents();
  }


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

  // Generate a unique key for each month
  String _getMonthKey(DateTime date) {
    return '${date.year}-${date.month}';
  }

  // Load events for a specific month from Firestore
  void _loadEventsForMonth(DateTime month) {
    final monthKey = _getMonthKey(month);

    // Check if already cached
    if (_monthlyEventsCache.containsKey(monthKey)) {
      setState(() {
        _currentMonthEvents = _monthlyEventsCache[monthKey]!;
      });
      return;
    }

    // Calculate month range
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // Create stream for this month's events
    _eventsStream = FirebaseFirestore.instance
        .collection('events')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth),
        )
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
        .snapshots();

    // Listen to stream and update events
    _eventsStream!.listen((snapshot) {
      final events = <DateTime, List<Event>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null || data['date'] == null) {
          continue; // Skip documents without a valid date
        }

        final timestamp = data['date'] as Timestamp;
        final eventDate = DateTime.utc(
          timestamp.toDate().year,
          timestamp.toDate().month,
          timestamp.toDate().day,
        );

        final event = Event(
          id: doc.id,
          title: data['title'] ?? 'Untitled Event',
          time: data['time'] ?? '',
          color: _getColorFromString(data['color'] ?? 'blue'),
          description: data['description'] ?? '',
        );

        if (events[eventDate] == null) {
          events[eventDate] = [];
        }
        events[eventDate]!.add(event);
      }

      setState(() {
        _currentMonthEvents = events;
        _monthlyEventsCache[monthKey] = events; // Cache the result
      });
    });
  }

  // Convert color string to Color object
  Color _getColorFromString(String colorStr) {
    switch (colorStr.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  // Get events for a specific day
  List<Event> _getEventsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _currentMonthEvents[key] ?? [];
  }

  // Called when user swipes to a different month
  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
    });

    // Load events for the new month
    _loadEventsForMonth(focusedDay);

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Loading events for ${DateFormat('MMMM yyyy').format(focusedDay)}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Handle day selection
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    final events = _getEventsForDay(selectedDay);

    if (events.isEmpty) {
      _showNoEventsDialog(selectedDay);
    } else {
      _showEventsDialog(selectedDay, events);
    }
  }

  // Dialog for when no events exist
  void _showNoEventsDialog(DateTime day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.event_busy, color: Colors.orange, size: 48),
        title: const Text('No Events'),
        content: Text(
          'There are no events scheduled for ${DateFormat('MMMM d, yyyy').format(day)}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Dialog showing event details
  void _showEventsDialog(DateTime day, List<Event> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          DateFormat('MMMM d, yyyy').format(day),
          style: const TextStyle(fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: event.color,
                    child: const Icon(Icons.event, color: Colors.white),
                  ),
                  title: Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.time),
                      if (event.description.isNotEmpty)
                        Text(
                          event.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Event Calendar'),
        centerTitle: true,
        elevation: 2,
        actions: [
          // Show current month and cache info
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cache Info'),
                  content: Text(
                    'Cached months: ${_monthlyEventsCache.length}\n'
                    'Current month: ${DateFormat('MMMM yyyy').format(_focusedDay)}\n'
                    'Events this month: ${_currentMonthEvents.values.fold(0, (sum, list) => sum + list.length)}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _monthlyEventsCache.clear();
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cache cleared')),
                        );
                      },
                      child: const Text('Clear Cache'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar Widget
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged:
                _onPageChanged, // This is key for month swipe detection
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.5),
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
              formatButtonVisible: true,
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

// Event model class
class Event {
  final String id;
  final String title;
  final String time;
  final Color color;
  final String description;

  Event({
    required this.id,
    required this.title,
    required this.time,
    required this.color,
    required this.description,
  });
}
