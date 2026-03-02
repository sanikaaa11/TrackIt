import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/journal_model.dart';

class JournalTab extends StatefulWidget {
  const JournalTab({super.key});

  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  final CollectionReference _journals =
      FirebaseFirestore.instance.collection('journals');

  final ImagePicker _picker = ImagePicker();

  final List<String> moods = ["😊", "🙂", "😐", "😔", "😤"];

  void _showJournalDialog({Journal? journal}) {
    final titleController =
        TextEditingController(text: journal?.title ?? "");
    final contentController =
        TextEditingController(text: journal?.content ?? "");

    String selectedMood = journal?.mood ?? "🙂";
    File? selectedImage;
    String? existingImagePath = journal?.imagePath;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title:
                  Text(journal == null ? "New Journal" : "Edit Journal"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: "Title"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                          labelText: "Write your thoughts..."),
                    ),
                    const SizedBox(height: 15),

                    /// Mood Selector
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceAround,
                      children: moods.map((mood) {
                        final selected = selectedMood == mood;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedMood = mood;
                            });
                          },
                          child: Text(
                            mood,
                            style: TextStyle(
                              fontSize: 26,
                              color: selected
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 15),

                    /// Image Picker
                    ElevatedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 60,
                                maxWidth: 800,
                              );

                              if (picked != null) {
                                setModalState(() {
                                  selectedImage = File(picked.path);
                                });
                              }
                            },
                      icon: const Icon(Icons.image),
                      label: const Text("Add Image"),
                    ),

                    const SizedBox(height: 10),

                    /// Preview
                    if (selectedImage != null)
                      _buildImagePreview(selectedImage!.path)
                    else if (existingImagePath != null)
                      _buildImagePreview(existingImagePath),

                    if (isSaving)
                      const Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (contentController.text
                              .trim()
                              .isEmpty) return;

                          setModalState(() {
                            isSaving = true;
                          });

                          String? finalImagePath =
                              selectedImage?.path ??
                                  existingImagePath;

                          if (journal == null) {
                            await _journals.add({
                              'title':
                                  titleController.text.trim(),
                              'content':
                                  contentController.text.trim(),
                              'mood': selectedMood,
                              'imagePath': finalImagePath,
                              'createdAt': Timestamp.now(),
                            });
                          } else {
                            await _journals
                                .doc(journal.id)
                                .update({
                              'title':
                                  titleController.text.trim(),
                              'content':
                                  contentController.text.trim(),
                              'mood': selectedMood,
                              'imagePath': finalImagePath,
                            });
                          }

                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                  child: Text(journal == null ? "Save" : "Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildImagePreview(String path) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _deleteJournal(String id) async {
    await _journals.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6FB1FC),
        onPressed: () => _showJournalDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _journals
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final journals = snapshot.data!.docs
              .map((doc) => Journal.fromFirestore(doc))
              .toList();

          if (journals.isEmpty) {
            return const Center(
                child: Text("Start your first journal ✍️"));
          }

          return ListView.builder(
            itemCount: journals.length,
            itemBuilder: (context, index) {
              final journal = journals[index];

              return Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(journal.mood,
                            style: const TextStyle(
                                fontSize: 28)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            journal.title.isEmpty
                                ? "Untitled Entry"
                                : journal.title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                              Icons.delete_outline),
                          onPressed: () =>
                              _deleteJournal(
                                  journal.id),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      journal.content,
                      style:
                          const TextStyle(height: 1.5),
                    ),
                    if (journal.imagePath != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 10),
                        child: _buildImagePreview(
                            journal.imagePath!),
                      )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}