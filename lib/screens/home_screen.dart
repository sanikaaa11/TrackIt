import 'package:flutter/material.dart';
import 'tasks/task_screen.dart';
import 'expenses/expense_screen.dart';
import 'notes/note_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TaskScreen(),
      const NoteScreen(),
      const ExpenseScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF6FB1FC),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: "Tasks",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note_alt_outlined),
            label: "Notes",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: "Expenses",
          ),
        ],
      ),
    );
  }
}