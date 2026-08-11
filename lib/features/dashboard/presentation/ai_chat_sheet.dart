import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../expenses/domain/expense_notifier.dart';
import '../../habits/domain/habit_notifier.dart';
import '../../journal/domain/journal_notifier.dart';
import '../../tasks/domain/task_notifier.dart';
import '../../../shared/ai_service.dart';

// SECURITY: Input validation constants for the chat interface
class _ChatInputLimits {
  static const int maxMessageLength = 500;
  static const int maxMessagesInSession = 50; // prevent memory bloat
  static const Duration sendDebounce = Duration(seconds: 2);
  static const Duration minTimeBetweenMessages = Duration(seconds: 1);
}

class AiChatSheet extends ConsumerStatefulWidget {
  const AiChatSheet({super.key});

  @override
  ConsumerState<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends ConsumerState<AiChatSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController messageController;
  late final ScrollController scrollController;
  late final AnimationController loadingController;

  List<Map<String, String>> messages = [];
  bool isLoading = false;

  // SECURITY: Rate limiting state — debounce send button
  DateTime? _lastSentAt;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    messageController = TextEditingController();
    scrollController = ScrollController();
    loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    loadingController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // SECURITY: Check if sending is allowed (debounce + rate limit)
  bool get _canSend {
  if (messageController.text.trim().isEmpty) return false;

  if (isLoading) return false;

  if (_lastSentAt != null &&
      DateTime.now().difference(_lastSentAt!) <
          _ChatInputLimits.minTimeBetweenMessages) {
    return false;
  }

  // SECURITY: Cap session message count
  if (messages.length >= _ChatInputLimits.maxMessagesInSession) {
    return false;
  }

  return true;
}

  Map<String, dynamic> _buildAppData() {
    final tasks = ref.read(tasksProvider);
    final expenses = ref.read(expensesProvider);
    final habits = ref.read(habitsProvider);
    final journal = ref.read(journalProvider);
    final budgetRepository = ref.read(expenseRepositoryProvider);
    final habitRepository = ref.read(habitRepositoryProvider);

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final pendingTasks = tasks.where((t) => !t.isComplete).length;
    final completedThisWeek = tasks
        .where((t) => t.isComplete && t.createdAt.isAfter(weekAgo))
        .length;

    final thisMonthExpenses = expenses
        .where((e) =>
            !e.isIncome &&
            e.date.month == now.month &&
            e.date.year == now.year)
        .toList();
    final monthlySpent =
        thisMonthExpenses.fold(0.0, (s, e) => s + e.amount);

    final categoryTotals = <String, double>{};
    for (final e in thisMonthExpenses) {
      categoryTotals[e.category] =
          (categoryTotals[e.category] ?? 0) + e.amount;
    }
    final topCategory = categoryTotals.isEmpty
        ? 'None'
        : categoryTotals.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

    var bestStreak = 0;
    for (final habit in habits) {
      final streak = habitRepository.getLongestStreak(habit.id);
      if (streak > bestStreak) bestStreak = streak;
    }

    final journalThisWeek = journal
        .where((e) {
          final date = DateTime.tryParse(e.date);
          return date != null && date.isAfter(weekAgo);
        })
        .toList();

    final avgMood = journalThisWeek.isEmpty
        ? 0.0
        : journalThisWeek
                .map((e) => e.moodScore)
                .reduce((a, b) => a + b) /
            journalThisWeek.length;

    // SECURITY: Return only aggregate data — no raw content
    return {
      'pendingTasks': pendingTasks,
      'completedThisWeek': completedThisWeek,
      'monthlyBudget': budgetRepository.getMonthlyBudget(),
      'monthlySpent': monthlySpent,
      'topCategory': topCategory,
      'habitCount': habits.length,
      'bestStreak': bestStreak,
      'journalCount': journalThisWeek.length,
      'avgMood': avgMood.toStringAsFixed(1),
    };
  }

  void _scrollToBottom() {
    if (!scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage([String? presetMessage]) async {
    // SECURITY: Enforce debounce — prevent rapid-fire API calls
    if (!_canSend && presetMessage == null) return;

    final rawMessage = presetMessage ?? messageController.text.trim();
    if (rawMessage.isEmpty) return;

    // SECURITY: Enforce max message length at UI level
    // (AI service also validates, but defense in depth)
    if (rawMessage.length > _ChatInputLimits.maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message too long — keep it under ${_ChatInputLimits.maxMessageLength} characters.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // SECURITY: Cap session message count
    if (messages.length >= _ChatInputLimits.maxMessagesInSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Session limit reached. Start a new conversation!'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    _lastSentAt = DateTime.now();

    setState(() {
      messages = [
        ...messages,
        {'role': 'user', 'text': rawMessage},
        {'role': 'loading', 'text': ''},
      ];
      isLoading = true;
      messageController.clear();
    });
    _scrollToBottom();

    final appData = _buildAppData();
    final response = await ref.read(aiServiceProvider).chatWithData(
          userMessage: rawMessage,
          appData: appData,
        );

    if (!mounted) return;

    setState(() {
      final loadingIndex =
          messages.indexWhere((m) => m['role'] == 'loading');
      if (loadingIndex != -1) {
        messages = List.from(messages)
          ..[loadingIndex] = {'role': 'ai', 'text': response};
      } else {
        messages = [...messages, {'role': 'ai', 'text': response}];
      }
      isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: FractionallySizedBox(
          heightFactor: 0.82,
          widthFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.md,
                    AppSizes.sm,
                    AppSizes.sm,
                    AppSizes.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.notes.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Text('✨',
                            style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'TrackIt AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // SECURITY: Show session message count
                      if (messages.isNotEmpty)
                        Text(
                          '${messages.where((m) => m['role'] == 'user').length}/${_ChatInputLimits.maxMessagesInSession ~/ 2}',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.border),

                // Suggestion chips
                if (messages.isEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: AppSizes.md),
                    child: Row(
                      children: [
                        _SuggestionChip(
                          label: '📊 How was my week?',
                          onTap: () => _sendMessage('How was my week?'),
                        ),
                        _SuggestionChip(
                          label: '💸 Where am I overspending?',
                          onTap: () =>
                              _sendMessage('Where am I overspending?'),
                        ),
                        _SuggestionChip(
                          label: '💪 Which habit needs work?',
                          onTap: () =>
                              _sendMessage('Which habit needs work?'),
                        ),
                        _SuggestionChip(
                          label: '🎯 What to focus on today?',
                          onTap: () => _sendMessage(
                              'What should I focus on today?'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: AppColors.border),
                ],

                // Messages
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🤖',
                                  style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                'Ask me anything about your data',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.all(AppSizes.md),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final role = message['role'] ?? 'ai';

                            if (role == 'loading') {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 120),
                                  margin:
                                      const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: _LoadingDots(
                                      animation: loadingController),
                                ),
                              );
                            }

                            final isUser = role == 'user';
                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width *
                                          (isUser ? 0.72 : 0.88),
                                ),
                                margin:
                                    const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? AppColors.tasks
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(isUser ? 16 : 4),
                                    bottomRight:
                                        Radius.circular(isUser ? 4 : 16),
                                  ),
                                ),
                                child: Text(
                                  message['text'] ?? '',
                                  style: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Input row
                Container(
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.md,
                    8,
                    AppSizes.md,
                    AppSizes.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(
                          color: AppColors.border, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          textCapitalization: TextCapitalization.sentences,
                          // SECURITY: Enforce max length at input level
                          maxLength: _ChatInputLimits.maxMessageLength,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Ask about your data...',
                            hintStyle: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 14,
                            ),
                            // Show character count when near limit
                            counterText: messageController.text.length >
                                    _ChatInputLimits.maxMessageLength - 50
                                ? '${messageController.text.length}/${_ChatInputLimits.maxMessageLength}'
                                : '',
                            counterStyle: TextStyle(
                              color: messageController.text.length >=
                                      _ChatInputLimits.maxMessageLength
                                  ? AppColors.error
                                  : AppColors.textHint,
                              fontSize: 10,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: AppColors.notes,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) =>
                              _canSend ? _sendMessage() : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        // SECURITY: Button disabled during loading OR debounce
                        onPressed: _canSend ? () => _sendMessage() : null,
                        icon: isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.tasks,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        color: AppColors.tasks,
                        disabledColor: AppColors.textHint,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.animation});

  final AnimationController animation;

  Widget _dot(int index) {
    final start = index * 0.2;
    final end = (start + 0.6).clamp(0.0, 1.0);
    final opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(start, end, curve: Curves.easeInOut),
      ),
    );
    return FadeTransition(
      opacity: opacity,
      child: Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.textSecondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, _dot),
    );
  }
}