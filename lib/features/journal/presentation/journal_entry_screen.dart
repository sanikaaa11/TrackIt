// ignore_for_file: unused_field

import 'dart:io';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../data/journal_model.dart';
import '../domain/journal_notifier.dart';

class JournalEntryScreen extends ConsumerStatefulWidget {
  const JournalEntryScreen({super.key, required this.date});

  final String date;

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  late final TextEditingController bodyController;
  String selectedMood = 'Good';
  List<String> imagePaths = [];
  JournalEntry? existingEntry;

  // New state for 3-step mood check-in
  
  double moodScore = 5.0;
  List<String> selectedEmotionTags = [];
  String energyLevel = 'Medium';

  Timer? _promptTimer;
  bool _showPrompt = false;

  static const List<Map<String, String>> moods = [
    {'mood': 'Great', 'emoji': '😄'},
    {'mood': 'Good', 'emoji': '🙂'},
    {'mood': 'Okay', 'emoji': '😐'},
    {'mood': 'Bad', 'emoji': '😔'},
    {'mood': 'Awful', 'emoji': '😢'},
  ];

  static const List<String> _emotionOptions = [
    '😴 Tired',
    '💸 Money stress',
    '📚 Exams / Work',
    '👥 People',
    '🏃 Health',
    '❤️ Relationships',
    '🎉 Something good',
    '🌤️ Just vibes',
  ];

  static const List<String> _guidedPrompts = [
    'What made today different from yesterday?',
    'Name one small win from today.',
    'Describe a moment that made you smile.',
    'What drained your energy today?',
    'What boosted your energy today?',
    'Who did you connect with today?',
    'What would you repeat from today?',
    'What did you learn about yourself today?',
    'What is one thing you wish you had more time for?',
    'List three things you’re grateful for.',
    'What is one thing you could let go of?',
    'Describe a challenge you faced and how you handled it.',
    'What’s one thing that surprised you today?',
    'How did you take care of your body today?',
    'What was your most creative moment today?',
    'If today had a soundtrack, what would it be?',
    'What’s a small goal for tomorrow?',
    'Describe a conversation that mattered today.',
    'What hobby did you think about but not do?',
    'What is one way you were kind to yourself?',
    'What’s a worry you can put aside for now?',
    'What energized you this week?',
    'What drained you this week?',
    'What are you looking forward to?',
    'What made you feel seen today?',
    'What was an awkward moment you can laugh about?',
    'What did you notice in nature today?',
    'How did you express creativity today?',
    'What’s one habit you’d like to start?',
    'What do you need to forgive yourself for?',
  ];

  String get _dateKey {
    if (widget.date == 'today') {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
    return widget.date;
  }

  DateTime get _displayDate {
    try {
      return DateTime.parse(_dateKey);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  void initState() {
    super.initState();
    bodyController = TextEditingController();
    _loadExistingEntry();
    _promptTimer = Timer(const Duration(seconds: 8), _handlePromptTimer);
  }

  void _loadExistingEntry() {
    final entries = ref.read(journalProvider);
    final entry = entries.where((e) => e.date == _dateKey).firstOrNull;
    if (entry == null) return;

    existingEntry = entry;
    selectedMood = entry.mood;
    bodyController.text = entry.body;
    imagePaths = List<String>.from(entry.imagePaths);
    // load new fields if present
    try {
      moodScore = (entry.moodScore).toDouble();
    } catch (_) {
      moodScore = 5.0;
    }
    selectedEmotionTags = List<String>.from(entry.emotionTags);
    energyLevel = entry.energyLevel;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (!mounted) return;
    setState(() {
      imagePaths = [...imagePaths, picked.path];
    });
  }

  Future<void> _saveEntry() async {
    // derive a 5-label mood from the numeric score so list emoji reflects choice
    selectedMood = _moodLabelForScore(moodScore);

    if (existingEntry != null) {
      existingEntry!
        ..mood = selectedMood
        ..body = bodyController.text.trim()
        ..imagePaths = List<String>.from(imagePaths)
        ..moodScore = moodScore.round()
        ..emotionTags = List<String>.from(selectedEmotionTags)
        ..energyLevel = energyLevel
        ..updatedAt = DateTime.now();
      await ref.read(journalProvider.notifier).saveEntry(existingEntry!);
    } else {
      final entry = JournalEntry.create(
        date: _dateKey,
        mood: selectedMood,
        body: bodyController.text.trim(),
        imagePaths: imagePaths,
        moodScore: moodScore.round(),
        emotionTags: selectedEmotionTags,
        energyLevel: energyLevel,
      );
      await ref.read(journalProvider.notifier).saveEntry(entry);
    }

    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    bodyController.dispose();
    super.dispose();
  }

  Color _colorForScore(double s) {
    if (s <= 3) return AppColors.error;
    if (s <= 5) return Colors.orange;
    if (s <= 7) return Colors.amber;
    return AppColors.expenses;
  }

  String _labelForScore(double s) {
    final v = s.round();
    if (v <= 2) return 'Really rough 😢';
    if (v <= 4) return 'Not great 😔';
    if (v <= 6) return 'Okay 😐';
    if (v <= 8) return 'Pretty good 🙂';
    return 'Amazing! 😄';
  }

  String _moodLabelForScore(double s) {
    final v = s.round();
    if (v <= 2) return 'Awful';
    if (v <= 4) return 'Bad';
    if (v <= 6) return 'Okay';
    if (v <= 8) return 'Good';
    return 'Great';
  }

  void _handlePromptTimer() {
    if (!mounted) return;
    if (bodyController.text.trim().isEmpty) {
      setState(() => _showPrompt = true);
      _showGuidedPrompt();
    }
  }

  Future<void> _showGuidedPrompt() async {
    if (!mounted) return;
  final prompts = List<String>.from(_guidedPrompts);
    prompts.shuffle();
    final prompt = prompts.first;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GestureDetector(
          onTap: () {},
          child: Container(
            margin: EdgeInsets.only(top: 100),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '✨ Need a nudge?',
                        style: TextStyle(
                          color: AppColors.journal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        icon: Icon(Icons.close),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(prompt, style: TextStyle(color: Colors.white)),
                  SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      bodyController.text = prompt;
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      'Use this prompt',
                      style: TextStyle(color: AppColors.journal),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (mounted) setState(() => _showPrompt = false);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          DateFormat('EEEE, MMMM d').format(_displayDate),
          style: TextStyle(
            color: AppColors.journal,
            fontWeight: FontWeight.bold,
            fontSize: AppSizes.fontLg,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveEntry,
            child: Text(
              'Done',
              style: TextStyle(
                color: AppColors.journal,
                fontSize: AppSizes.fontMd,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW ARE YOU FEELING?',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Slider(
                      min: 1,
                      max: 10,
                      divisions: 9,
                      value: moodScore,
                      activeColor: _colorForScore(moodScore),
                      onChanged: (v) => setState(() => moodScore = v),
                    ),
                    Center(
                      child: Text(
                        _labelForScore(moodScore),
                        style: TextStyle(
                          color: _colorForScore(moodScore),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "WHAT'S DRIVING THIS?",
                      style: TextStyle(color: AppColors.textHint, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _emotionOptions.map((label) {
                        final selected = selectedEmotionTags.contains(label);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                selectedEmotionTags.remove(label);
                              } else {
                                selectedEmotionTags.add(label);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.journal
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ENERGY LEVEL',
                      style: TextStyle(color: AppColors.textHint, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: ['🪫 Low', '⚡ Medium', '🔋 High'].map((label) {
                        final isSelected =
                            (label.contains('Low') && energyLevel == 'Low') ||
                            (label.contains('Medium') &&
                                energyLevel == 'Medium') ||
                            (label.contains('High') && energyLevel == 'High');
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (label.contains('Low')) energyLevel = 'Low';
                                if (label.contains('Medium'))
                                  energyLevel = 'Medium';
                                if (label.contains('High'))
                                  energyLevel = 'High';
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.journal.withOpacity(0.2)
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: AppColors.journal,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bodyController,
                      minLines: 6,
                      maxLines: null,
                      scrollPadding: const EdgeInsets.only(bottom: 200),
                      textCapitalization: TextCapitalization.sentences,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppSizes.fontLg,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Start writing...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppSizes.fontLg,
                        ),
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: keyboardVisible ? 0 : 100,
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: keyboardVisible ? 0 : 1,
                child: keyboardVisible
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: imagePaths.length + 1,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            if (index == imagePaths.length) {
                              return _AddImageButton(onTap: _pickImage);
                            }

                            final path = imagePaths[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusSm,
                                  ),
                                  child: Image.file(
                                    File(path),
                                    width: 80,
                                    height: 80,
                                    cacheWidth: 160,
                                    cacheHeight: 160,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusSm,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: AppColors.textHint,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        imagePaths.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddImageButton extends StatelessWidget {
  const _AddImageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DottedBorderPainter(),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: Icon(
            Icons.add_photo_alternate_outlined,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = AppColors.textHint
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(AppSizes.radiusSm),
    );

    void drawDashedLine(Offset start, Offset end) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final length = math.sqrt(dx * dx + dy * dy);
      final vx = dx / length;
      final vy = dy / length;

      double distance = 0;
      while (distance < length) {
        final next = (distance + dashWidth).clamp(0, length);
        final from = Offset(start.dx + vx * distance, start.dy + vy * distance);
        final to = Offset(start.dx + vx * next, start.dy + vy * next);
        canvas.drawLine(from, to, paint);
        distance += dashWidth + dashSpace;
      }
    }

    final bounds = rect.outerRect;
    drawDashedLine(bounds.topLeft, bounds.topRight);
    drawDashedLine(bounds.topRight, bounds.bottomRight);
    drawDashedLine(bounds.bottomRight, bounds.bottomLeft);
    drawDashedLine(bounds.bottomLeft, bounds.topLeft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}
