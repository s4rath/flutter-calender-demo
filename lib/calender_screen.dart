
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

  // Sample events - Replace this with your actual data source
  final Map<DateTime, List<Event>> _events = {
    DateTime.utc(2025, 12, 5): [
      Event('Team Meeting', '10:00 AM', Colors.blue),
      Event('Project Review', '2:00 PM', Colors.green),
    ],
    DateTime.utc(2025, 12, 10): [
      Event('Client Presentation', '11:00 AM', Colors.orange),
    ],
    DateTime.utc(2025, 12, 15): [
      Event('Birthday Party', '6:00 PM', Colors.pink),
    ],
    DateTime.utc(2025, 12, 20): [
      Event('Dentist Appointment', '3:00 PM', Colors.red),
    ],
    DateTime.utc(2025, 12, 25): [
      Event('Christmas Celebration', 'All Day', Colors.red),
    ],
    DateTime.utc(2025, 1, 1): [
      Event('New Year Party', '11:00 PM', Colors.purple),
    ],
  };

  // Get events for a specific day
  List<Event> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  // Show event details or warning
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    final events = _getEventsForDay(selectedDay);

    if (events.isEmpty) {
      // Show warning when no events
      _showNoEventsDialog(selectedDay);
    } else {
      // Show event details
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
                  subtitle: Text(event.time),
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
        title: const Text('Event Calendar'),
        centerTitle: true,
        elevation: 2,
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
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: _getEventsForDay,
            // Styling
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
            // Custom event markers
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
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Tap on any date to view events',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dates with red dots have events scheduled',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
  final String title;
  final String time;
  final Color color;

  Event(this.title, this.time, this.color);
}
