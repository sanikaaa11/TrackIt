import 'package:cloud_firestore/cloud_firestore.dart';

class Journal {
  final String id;
  final String title;
  final String content;
  final String mood;
  final String? imagePath;
  final DateTime date;

  Journal({
    required this.id,
    required this.title,
    required this.content,
    required this.mood,
    this.imagePath,
    required this.date,
  });

  factory Journal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Journal(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      mood: data['mood'] ?? '🙂',
      imagePath: data['imagePath'],
      date: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}