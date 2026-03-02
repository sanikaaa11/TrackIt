import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class JournalCalendarScreen extends StatefulWidget {
  const JournalCalendarScreen({super.key});

  @override
  State<JournalCalendarScreen> createState() =>
      _JournalCalendarScreenState();
}

class _JournalCalendarScreenState
    extends State<JournalCalendarScreen> {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal Calendar"),
        backgroundColor: const Color(0xFF6FB1FC),
      ),
      body: TableCalendar(
        focusedDay: focusedDay,
        firstDay: DateTime(2020),
        lastDay: DateTime(2100),
        selectedDayPredicate: (day) =>
            isSameDay(selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() {
            selectedDay = selected;
            focusedDay = focused;
          });
        },
      ),
    );
  }
}