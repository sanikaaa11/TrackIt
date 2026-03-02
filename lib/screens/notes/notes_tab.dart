import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/note_model.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final CollectionReference _notes =
      FirebaseFirestore.instance.collection('notes');

  void _showNoteDialog({Note? note}) {
    final titleController =
        TextEditingController(text: note?.title ?? "");
    final contentController =
        TextEditingController(text: note?.content ?? "");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(note == null ? "Add Note" : "Edit Note"),
          content: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration:
                        const InputDecoration(labelText: "Title"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration:
                        const InputDecoration(labelText: "Content"),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();

                if (title.isEmpty && content.isEmpty) return;

                if (note == null) {
                  await _notes.add({
                    'title': title,
                    'content': content,
                    'createdAt': Timestamp.now(),
                    'updatedAt': Timestamp.now(),
                  });
                } else {
                  await _notes.doc(note.id).update({
                    'title': title,
                    'content': content,
                    'updatedAt': Timestamp.now(),
                  });
                }

                Navigator.pop(context);
              },
              child: Text(note == null ? "Add" : "Update"),
            ),
          ],
        );
      },
    );
  }

  void _deleteNote(String id) async {
    await _notes.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notes
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data!.docs
              .map((doc) => Note.fromFirestore(doc))
              .toList();

          if (notes.isEmpty) {
            return const Center(
              child: Text("No notes yet.\nTap + to add one."),
            );
          }

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  onTap: () => _showNoteDialog(note: note),
                  title: Text(
                    note.title.isEmpty ? "Untitled" : note.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(
                        note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${note.updatedAt.day}/${note.updatedAt.month}/${note.updatedAt.year}",
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () =>
                        _deleteNote(note.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6FB1FC),
        onPressed: () => _showNoteDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}