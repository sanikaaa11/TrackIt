import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/task_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final CollectionReference _tasks =
      FirebaseFirestore.instance.collection('tasks');

  String _filter = "All";

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.red;
      case "Medium":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _filter == label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected ? const Color(0xFF6FB1FC) : Colors.grey.shade300,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () {
          setState(() {
            _filter = label;
          });
        },
        child: Text(label),
      ),
    );
  }

  void _addTask(BuildContext context) {
    String input = "";
    String priority = "Low";
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Task"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => input = value,
                  decoration:
                      const InputDecoration(labelText: "Task Title"),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: priority,
                  items: ["Low", "Medium", "High"]
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    priority = value!;
                  },
                  decoration:
                      const InputDecoration(labelText: "Priority"),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      dueDate = picked;
                    }
                  },
                  child:
                      const Text("Select Due Date (Optional)"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (input.trim().isNotEmpty) {

                  // 1️⃣ Save to Firestore
                  await _tasks.add({
                    'title': input.trim(),
                    'isCompleted': false,
                    'priority': priority,
                    'createdAt': Timestamp.now(),
                    'dueDate': dueDate != null
                        ? Timestamp.fromDate(dueDate!)
                        : null,
                  });

                  // 2️⃣ Call FastAPI
                  final response = await http.post(
                    Uri.parse("http://192.168.43.184:8000/task"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "title": input.trim(),
                      "priority": priority,
                    }),
                  );

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(data["message"]),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("API Error"),
                      ),
                    );
                  }
                }

                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _toggleTask(Task task) async {
    await _tasks.doc(task.id).update({
      'isCompleted': !task.isCompleted,
    });
  }

  void _deleteTask(String id) async {
    await _tasks.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Tasks"),
        backgroundColor: const Color(0xFF6FB1FC),
      ),
      body: Column(
        children: [
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterButton("All"),
              _buildFilterButton("Pending"),
              _buildFilterButton("Completed"),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _tasks
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text("Something went wrong"));
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                List<Task> tasks = snapshot.data!.docs
                    .map((doc) => Task.fromFirestore(doc))
                    .toList();

                if (_filter == "Pending") {
                  tasks = tasks
                      .where((t) => !t.isCompleted)
                      .toList();
                } else if (_filter == "Completed") {
                  tasks = tasks
                      .where((t) => t.isCompleted)
                      .toList();
                }

                if (tasks.isEmpty) {
                  return const Center(
                    child: Text(
                        "No tasks found.\nTry adding one."),
                  );
                }

                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value:
                                      task.isCompleted,
                                  onChanged: (_) =>
                                      _toggleTask(task),
                                ),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w500,
                                      decoration: task
                                              .isCompleted
                                          ? TextDecoration
                                              .lineThrough
                                          : TextDecoration
                                              .none,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete),
                                  onPressed: () =>
                                      _deleteTask(
                                          task.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                              horizontal:
                                                  10,
                                              vertical:
                                                  4),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        _getPriorityColor(
                                            task
                                                .priority),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                                20),
                                  ),
                                  child: Text(
                                    task.priority,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                    width: 10),
                                if (task.dueDate !=
                                    null)
                                  Text(
                                    "Due: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}",
                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton(
        backgroundColor:
            const Color(0xFF6FB1FC),
        onPressed: () => _addTask(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}