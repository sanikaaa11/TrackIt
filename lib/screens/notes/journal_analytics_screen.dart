import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class JournalAnalyticsScreen extends StatelessWidget {
  const JournalAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journals =
        FirebaseFirestore.instance.collection('journals');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mood Analytics"),
        backgroundColor: const Color(0xFF6FB1FC),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: journals.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          Map<String, int> moodCount = {};

          for (var doc in docs) {
            final mood = doc['mood'];
            moodCount[mood] =
                (moodCount[mood] ?? 0) + 1;
          }

          return PieChart(
            PieChartData(
              sections: moodCount.entries
                  .map(
                    (e) => PieChartSectionData(
                      value: e.value.toDouble(),
                      title: e.key,
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}