import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final bool isCompleted;
  final String priority;
  final DateTime createdAt;
  final DateTime? dueDate;

  Task({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.priority,
    required this.createdAt,
    this.dueDate,
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      priority: data['priority'] ?? 'Low',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isCompleted': isCompleted,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate':
          dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    };
  }
}