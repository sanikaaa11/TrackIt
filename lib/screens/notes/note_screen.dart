import 'package:flutter/material.dart';
import 'notes_tab.dart';
import 'journal_tab.dart';

class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text("Notes"),
          backgroundColor: const Color(0xFF6FB1FC),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Notes"),
              Tab(text: "Journal"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NotesTab(),
            JournalTab(),
          ],
        ),
      ),
    );
  }
}