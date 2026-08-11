// ignore_for_file: dead_code

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../data/journal_model.dart';
import '../domain/journal_notifier.dart';

class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  Future<void> _openDatePicker(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null || !context.mounted) return;

    context.push('/journal/entry/${DateFormat('yyyy-MM-dd').format(selected)}');
  }

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen> {
  bool _graphExpanded = false;

  int calculateWordCount(List<JournalEntry> entries) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final thisWeekEntries = entries.where((e) {
      final entryDate = DateTime.parse(e.date);
      return entryDate.isAfter(weekAgo);
    }).toList();

    int totalWords = 0;
    for (final entry in thisWeekEntries) {
      if (entry.body.trim().isNotEmpty) {
        totalWords += entry.body.trim().split(RegExp(r'\s+')).length;
      }
    }
    return totalWords;
  }

  int calculateLongestEntry(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;
    return entries
        .map(
          (e) => e.body.trim().isEmpty
              ? 0
              : e.body.trim().split(RegExp(r'\s+')).length,
        )
        .reduce((a, b) => a > b ? a : b);
  }

  int calculateStreak(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;

    int streak = 0;
    DateTime checkDate = DateTime.now();

    while (true) {
      final dateStr =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      final hasEntry = entries.any((e) => e.date == dateStr);
      if (!hasEntry) break;
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(journalProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Journal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => widget._openDatePicker(context),
            icon: Icon(Icons.calendar_month, color: AppColors.journal),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.journal,
                    size: 64,
                  ),
                  SizedBox(height: AppSizes.md),
                  const Text(
                    'Your story starts today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppSizes.xs),
                  Text(
                    'Tap + to write your first entry',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppSizes.fontMd,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.all(AppSizes.md),
              children: [
                // Top sections
                if (_buildOnThisDay(entries) != null) ...[
                  _buildOnThisDay(entries)!,
                ],

                _buildMoodGraph(entries),

                _buildWritingStats(entries),

                SizedBox(height: AppSizes.sm),
                Text(
                  'YOUR ENTRIES',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: AppSizes.fontXs,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: AppSizes.xs),

                // Entries list
                ...entries.map((entry) => _JournalCard(entry: entry)).toList(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.journal,
        onPressed: () => context.push('/journal/entry/today'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget? _buildOnThisDay(List<JournalEntry> entries) {
    if (entries.isEmpty) return null;
    final now = DateTime.now();
    final prevMonth = now.month == 1 ? 12 : now.month - 1;

    JournalEntry? found;
    for (final e in entries) {
      try {
        final d = DateTime.parse(e.date);
        if (d.day == now.day &&
            (d.month == now.month || d.month == prevMonth) &&
            d.year != now.year) {
          found = e;
          break;
        }
      } catch (_) {}
    }

    if (found == null) return null;

    final summary = (found.body.length > 80)
        ? '${found.body.substring(0, 80)}...'
        : found.body;

    return GestureDetector(
      onTap: () => context.push('/journal/entry/${found!.date}'),
      child: Container(
        margin: EdgeInsets.only(bottom: AppSizes.md),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.journal, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🌱', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'On this day',
                        style: TextStyle(
                          color: AppColors.journal,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_relativeTime(found.date)} you were feeling ${found.mood}',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              summary,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(String date) {
    try {
      final d = DateTime.parse(date);
      final now = DateTime.now();
      final diffMonths = (now.year - d.year) * 12 + (now.month - d.month);
      if (diffMonths == 0) return 'This month';
      if (diffMonths == 1) return '1 month ago';
      return '$diffMonths months ago';
    } catch (_) {
      return '';
    }
  }

  Widget _buildMoodGraph(List<JournalEntry> entries) {
    final now = DateTime.now();
    final monthEntries = entries.where((e) {
      try {
        final d = DateTime.parse(e.date);
        return d.month == now.month && d.year == now.year;
      } catch (_) {
        return false;
      }
    }).toList();

    final spots = <FlSpot>[];
    for (final e in monthEntries) {
      try {
        final d = DateTime.parse(e.date);
        final x = d.day.toDouble();
        final y = (e.moodScore).toDouble();
        spots.add(FlSpot(x, y));
      } catch (_) {}
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.md),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Mood this month',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: () =>
                    setState(() => _graphExpanded = !_graphExpanded),
                icon: Icon(
                  _graphExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (_graphExpanded) ...[
            SizedBox(height: 12),
            if (spots.length <= 1)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.show_chart, color: AppColors.journal, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Write more entries to see your mood trend',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              AspectRatio(
                aspectRatio: 2.5,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.journal,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: AppColors.journal,
                              );
                            },
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchCallback: (event, response) {
                          if (response == null || response.lineBarSpots == null)
                            return;
                          final spot = response.lineBarSpots!.first;
                          final day = spot.x.toInt();
                          final target = DateTime(now.year, now.month, day);
                          final dateKey = DateFormat(
                            'yyyy-MM-dd',
                          ).format(target);
                          if (context.mounted)
                            context.push('/journal/entry/$dateKey');
                        },
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touches) {
                            return touches.map((barSpot) {
                              final day = barSpot.x.toInt();
                              final score = barSpot.y.toInt();
                              final target = DateTime(now.year, now.month, day);
                              final dateStr = DateFormat(
                                'MMM d',
                              ).format(target);
                              return LineTooltipItem(
                                'Mood: $score\n$dateStr',
                                TextStyle(color: Colors.white, fontSize: 12),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        horizontalInterval: 2,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: AppColors.border,
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWritingStats(List<JournalEntry> entries) {
    final wordsThisWeek = calculateWordCount(entries);
    final longest = calculateLongestEntry(entries);
    final streak = calculateStreak(entries);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statChip('📝 $wordsThisWeek words this week'),
        _statChip('🔥 $streak day streak'),
        _statChip('📖 Longest: $longest words'),
      ],
    );
  }

  Widget _statChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _JournalCard extends ConsumerWidget {
  const _JournalCard({required this.entry});

  final JournalEntry entry;

  static const Map<String, String> moodEmojis = {
    'Great': '😄',
    'Good': '🙂',
    'Okay': '😐',
    'Bad': '😔',
    'Awful': '😢',
  };

  String _formattedDate(String value) {
    try {
      final parsed = DateTime.parse(value);
      return DateFormat('EEEE, MMMM d').format(parsed);
    } catch (_) {
      return value;
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete entry?'),
          content: const Text('This entry will be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _deleteEntry(BuildContext context, WidgetRef ref) async {
    await ref.read(journalProvider.notifier).deleteEntry(entry.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(journalProvider.notifier).saveEntry(entry);
          },
        ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    if (!await _confirmDelete(context)) return;
    await _deleteEntry(context, ref);
  }

  Future<void> _showActionsSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_outlined, color: AppColors.journal),
                title: const Text('Edit entry'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/journal/entry/${entry.date}');
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(
                  'Delete entry',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _handleDelete(context, ref);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodEmoji = moodEmojis[entry.mood] ?? '🙂';

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: AppSizes.md - AppSizes.xs),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteEntry(context, ref),
      child: GestureDetector(
        onTap: () => context.push('/journal/entry/${entry.date}'),
        onLongPress: () => _showActionsSheet(context, ref),
        child: Container(
          margin: EdgeInsets.only(bottom: AppSizes.md - AppSizes.xs),
          padding: EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border(
              left: BorderSide(color: AppColors.journal, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _formattedDate(entry.date),
                    style: TextStyle(
                      color: AppColors.journal,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                      vertical: AppSizes.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    ),
                    child: Text(
                      moodEmoji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, height: 1),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.sm),
              Text(
                entry.body.isEmpty ? 'No entry text yet.' : entry.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppSizes.fontMd,
                ),
              ),
              if (entry.imagePaths.isNotEmpty) ...[
                SizedBox(height: AppSizes.sm),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entry.imagePaths.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(width: AppSizes.sm),
                    itemBuilder: (context, index) {
                      final path = entry.imagePaths[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        child: Image.file(
                          File(path),
                          width: 60,
                          height: 60,
                          cacheWidth: 120,
                          cacheHeight: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: AppColors.surfaceVariant,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textHint,
                                size: AppSizes.iconSm,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
