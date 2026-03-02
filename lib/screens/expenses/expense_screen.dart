import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/expense_model.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final CollectionReference _expenses =
      FirebaseFirestore.instance.collection('expenses');

  final List<String> categories = [
    "Food",
    "Transport",
    "Shopping",
    "Education",
    "Health",
    "Other",
  ];

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Food":
        return Icons.fastfood;
      case "Transport":
        return Icons.directions_car;
      case "Shopping":
        return Icons.shopping_bag;
      case "Education":
        return Icons.school;
      case "Health":
        return Icons.local_hospital;
      default:
        return Icons.receipt_long;
    }
  }

  void _addExpense(BuildContext context) {
    String title = "";
    String amount = "";
    String category = "Other";
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Expense"),
          content: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) => title = value,
                    decoration:
                        const InputDecoration(labelText: "Title"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => amount = value,
                    decoration:
                        const InputDecoration(labelText: "Amount"),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    items: categories
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            ))
                        .toList(),
                    onChanged: (value) => category = value!,
                    decoration:
                        const InputDecoration(labelText: "Category"),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        selectedDate = picked;
                      }
                    },
                    child: const Text("Select Date"),
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
                if (title.isNotEmpty && amount.isNotEmpty) {
                  await _expenses.add({
                    'title': title,
                    'amount': double.parse(amount),
                    'category': category,
                    'date': Timestamp.fromDate(selectedDate),
                    'createdAt': Timestamp.now(),
                  });
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

  double _calculateMonthlyTotal(List<Expense> expenses) {
    final now = DateTime.now();
    return expenses
        .where((e) =>
            e.date.month == now.month &&
            e.date.year == now.year)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Expenses"),
        backgroundColor: const Color(0xFF6FB1FC),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _expenses
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data!.docs
              .map((doc) => Expense.fromFirestore(doc))
              .toList();

          final monthlyTotal = _calculateMonthlyTotal(expenses);

          return Column(
            children: [
              const SizedBox(height: 15),

              // Monthly Total Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6FB1FC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Total This Month",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "₹ ${monthlyTotal.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              Expanded(
                child: expenses.isEmpty
                    ? const Center(child: Text("No expenses yet."))
                    : ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: Icon(
                                _getCategoryIcon(expense.category),
                                color: const Color(0xFF6FB1FC),
                              ),
                              title: Text(expense.title),
                              subtitle: Text(
                                "${expense.date.day}/${expense.date.month}/${expense.date.year}",
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "₹ ${expense.amount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () =>
                                        _expenses.doc(expense.id).delete(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6FB1FC),
        onPressed: () => _addExpense(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}