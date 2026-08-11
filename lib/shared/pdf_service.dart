// ignore_for_file: unused_import

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../features/expenses/data/expense_model.dart';

final pdfServiceProvider = Provider((ref) => PdfService());

class PdfService {
  Future<void> exportExpenseReport({
    required List<Expense> expenses,
    required double monthlyBudget,
    required String monthYear,
    required Map<String, double> categoryTotals,
  }) async {
    final pdf = pw.Document();
    final totalSpent = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final remaining = monthlyBudget - totalSpent;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TrackIt',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Expense Report — $monthYear',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Generated ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            children: [
              _summaryCard('Total Spent', '₹${totalSpent.toStringAsFixed(0)}'),
              pw.SizedBox(width: 16),
              _summaryCard(
                'Monthly Budget',
                '₹${monthlyBudget.toStringAsFixed(0)}',
              ),
              pw.SizedBox(width: 16),
              _summaryCard('Remaining', '₹${remaining.toStringAsFixed(0)}'),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Spending by Category',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...categoryTotals.entries.map(
            (entry) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(entry.key, style: const pw.TextStyle(fontSize: 13)),
                  pw.Text(
                    '₹${entry.value.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'All Transactions',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: ['Date', 'Category', 'Note', 'Amount']
                    .map(
                      (heading) => pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          heading,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...expenses.map(
                (expense) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        DateFormat('dd MMM').format(expense.date),
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        expense.category,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        expense.note ?? '-',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '₹${expense.amount.toStringAsFixed(0)}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final directory = await getTemporaryDirectory();
    final fileName = 'TrackIt_Expenses_$monthYear.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static pw.Widget _summaryCard(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
