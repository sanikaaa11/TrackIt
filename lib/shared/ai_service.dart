// ignore_for_file: unused_field

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../features/journal/data/journal_model.dart';


final aiServiceProvider = Provider<AIService>((ref) {
  const apiKey = String.fromEnvironment('GEMINI_KEY', defaultValue: '');
  return AIService(apiKey);
});


class _InputLimits {
  static const int maxUserMessage = 500;      // chars per AI chat message
  static const int maxTaskTitle = 100;        // chars
  static const int maxJournalBody = 5000;     // chars per entry sent to AI
  static const int maxCategoryName = 50;      // chars
  static const int maxEntriesPerSummary = 7;  // journal entries per AI call
  static const int maxTasksPerSuggestion = 20; // tasks sent to AI
}


class _RateLimiter {
  final Map<String, DateTime> _lastCalled = {};
  final Map<String, int> _callCount = {};
  final Map<String, DateTime> _windowStart = {};


  bool check(String method, {
    Duration minInterval = const Duration(seconds: 2),
    int maxCallsPerMinute = 10,
  }) {
    final now = DateTime.now();
    final lastCall = _lastCalled[method];

    // Enforce minimum interval between calls (debounce)
    if (lastCall != null && now.difference(lastCall) < minInterval) {
      return false;
    }

    // Enforce per-minute call limit (rate limit)
    final windowStart = _windowStart[method];
    if (windowStart == null || now.difference(windowStart).inMinutes >= 1) {
      _windowStart[method] = now;
      _callCount[method] = 0;
    }

    final count = _callCount[method] ?? 0;
    if (count >= maxCallsPerMinute) {
      return false;
    }

    _lastCalled[method] = now;
    _callCount[method] = count + 1;
    return true;
  }
}

class AIService {
  final String _apiKey;
  final _RateLimiter _rateLimiter = _RateLimiter();

  AIService(this._apiKey) {
    // Debug only — never log the full key in production
    assert(() {
      // ignore: avoid_print
      print('AIService init — key configured: ${_apiKey.isNotEmpty}');
      return true;
    }());
  }

  GenerativeModel get _model => GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

  // SECURITY: Sanitize user input before sending to external API.
  // Removes control characters, trims whitespace, enforces length limit.
  String _sanitize(String input, {int maxLength = 500}) {
    return input
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // control chars
        .trim()
        .substring(0, input.trim().length.clamp(0, maxLength));
  }

  // SECURITY: Validate that a string is within expected bounds
  // and contains no obviously malicious content.
  bool _isValidInput(String input, {int maxLength = 500}) {
    if (input.trim().isEmpty) return false;
    if (input.length > maxLength) return false;
    // Reject inputs that look like prompt injection attempts
    final injectionPatterns = RegExp(
      r'(ignore previous|disregard|system prompt|you are now|act as|jailbreak)',
      caseSensitive: false,
    );
    if (injectionPatterns.hasMatch(input)) return false;
    return true;
  }

  // Gen Z personality system prompt — injected into every request
  static const String _personality = '''
You are TrackIt AI, a chill, supportive productivity assistant for a gen z audience.

Your vibe:
- Talk like a smart friend who actually cares, not a corporate bot
- Keep it real and direct — no fluff, no filler phrases like "Certainly!" or "Great question!"
- Use emojis naturally but don't overdo it (1-2 per response max)
- Be encouraging without being fake

Your formatting (ALWAYS follow):
- Start with one punchy summary line
- Short paragraphs (2-3 lines max)
- For lists: use → prefix with line breaks
- NEVER use markdown bold (**), headers (#), or code blocks
- End with one short actionable tip or encouraging line
- Max 160 words total
''';

  Future<String> chatWithData({
    required String userMessage,
    required Map<String, dynamic> appData,
  }) async {
    // SECURITY: Rate limit chat endpoint — max 10 calls/min, 2s debounce
    if (!_rateLimiter.check('chatWithData',
        minInterval: const Duration(seconds: 2),
        maxCallsPerMinute: 10)) {
      return 'Slow down a little — sending too fast! Wait a sec and try again.';
    }

    // SECURITY: Validate and sanitize user message
    if (!_isValidInput(userMessage, maxLength: _InputLimits.maxUserMessage)) {
      return 'Message too long or contains unsupported characters. Keep it under 500 chars!';
    }
    final sanitizedMessage = _sanitize(
      userMessage,
      maxLength: _InputLimits.maxUserMessage,
    );

    if (_apiKey.isEmpty) {
      return 'TrackIt AI needs a Gemini API key to work. Configure it and restart the app.';
    }

    // SECURITY: Only send aggregate counts/averages to Gemini —
    // never raw note content, journal text, or personal identifiers.
    final hasData = (appData['pendingTasks'] ?? 0) > 0 ||
        (appData['monthlySpent'] ?? 0) > 0 ||
        (appData['habitCount'] ?? 0) > 0 ||
        (appData['journalCount'] ?? 0) > 0;

    final contextString = hasData
        ? '''User data summary (aggregated, no personal content):
- Pending tasks: ${(appData['pendingTasks'] ?? 0).clamp(0, 9999)}
- Tasks done this week: ${(appData['completedThisWeek'] ?? 0).clamp(0, 9999)}
- Monthly budget: ₹${(appData['monthlyBudget'] ?? 0).clamp(0, 9999999)}
- Spent this month: ₹${(appData['monthlySpent'] ?? 0).clamp(0, 9999999)}
- Top category: ${_sanitize(appData['topCategory']?.toString() ?? 'None', maxLength: _InputLimits.maxCategoryName)}
- Active habits: ${(appData['habitCount'] ?? 0).clamp(0, 100)}
- Best streak: ${(appData['bestStreak'] ?? 0).clamp(0, 9999)} days
- Journal entries this week: ${(appData['journalCount'] ?? 0).clamp(0, 100)}
- Avg mood this week: ${_sanitize(appData['avgMood']?.toString() ?? 'unknown', maxLength: 10)}/10'''
        : 'User just started — no data yet. Encourage them warmly to begin.';

    final prompt = '''$_personality

$contextString

User: $sanitizedMessage''';

    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15)); // SECURITY: timeout prevents hanging

      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return 'Got an empty response 😅 Try again!';
      }
      return _cleanResponse(text);
    } on TimeoutException {
      return 'AI took too long to respond. Check your connection and try again.';
    } catch (e) {
      return 'Connection issue rn 📡 Check your internet and try again.';
    }
  }

  Future<String> getTaskPrioritySuggestion(
    List<String> taskTitles,
    List<String?> dueDates,
  ) async {
    // SECURITY: Rate limit — AI suggestions max 5/min
    if (!_rateLimiter.check('taskSuggestion',
        minInterval: const Duration(seconds: 3),
        maxCallsPerMinute: 5)) {
      return 'Getting suggestions too fast — wait a moment and try again.';
    }

    if (_apiKey.isEmpty) return 'AI unavailable: API key not configured.';

    // SECURITY: Cap number of tasks sent to API and sanitize each title
    final cappedTitles = taskTitles
        .take(_InputLimits.maxTasksPerSuggestion)
        .map((t) => _sanitize(t, maxLength: _InputLimits.maxTaskTitle))
        .where((t) => t.isNotEmpty)
        .toList();

    if (cappedTitles.isEmpty) return 'No tasks to analyse yet!';

    final tasks = List.generate(cappedTitles.length, (i) {
      final due = i < dueDates.length ? dueDates[i] : null;
      return due == null || due.isEmpty
          ? '• ${cappedTitles[i]}'
          : '• ${cappedTitles[i]} (due: $due)';
    }).join('\n');

    final prompt =
        '$_personality\n\nPending tasks:\n$tasks\n\nWhich 3 should they focus on today and why? Be specific and direct.';

    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15));
      return _cleanResponse(response.text?.trim() ?? 'No response');
    } on TimeoutException {
      return 'Request timed out. Try again!';
    } catch (e) {
      return 'Can\'t reach AI rn — check your connection.';
    }
  }

  Future<String> getExpenseSuggestions(
    Map<String, double> categoryTotals,
    double budget,
  ) async {
    if (!_rateLimiter.check('expenseSuggestion',
        minInterval: const Duration(seconds: 3),
        maxCallsPerMinute: 5)) {
      return 'Getting suggestions too fast — wait a moment.';
    }

    if (_apiKey.isEmpty) return 'AI unavailable: API key not configured.';

    // SECURITY: Validate budget is a reasonable number
    final safeBudget = budget.clamp(0, 10000000);

    // SECURITY: Sanitize category names, cap number of categories
    final safeCategories = categoryTotals.entries
        .take(20)
        .map((e) {
          final name = _sanitize(e.key, maxLength: _InputLimits.maxCategoryName);
          final amount = e.value.clamp(0, 10000000);
          return '• $name: ₹${amount.toStringAsFixed(0)}';
        })
        .join('\n');

    final prompt =
        '$_personality\n\nMonthly budget: ₹$safeBudget\nSpending:\n$safeCategories\n\nGive 3 specific money-saving tips based on their actual numbers. Be honest but kind.';

    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15));
      return _cleanResponse(response.text?.trim() ?? 'No response');
    } on TimeoutException {
      return 'Request timed out. Try again!';
    } catch (e) {
      return 'Can\'t reach AI rn — check your connection.';
    }
  }

  Future<String> getMoodSummary(List<JournalEntry> weekEntries) async {
    if (!_rateLimiter.check('moodSummary',
        minInterval: const Duration(seconds: 5),
        maxCallsPerMinute: 3)) {
      return 'Getting summaries too fast — wait a moment.';
    }

    if (_apiKey.isEmpty) return 'AI unavailable: API key not configured.';

    if (weekEntries.isEmpty) {
      return 'No journal entries this week yet 📓\n\nStart writing — even just a few sentences counts.';
    }

    // SECURITY: Cap entries, send only metadata not full content
    // Full journal text is private — only send mood score, energy, tags
    final capped = weekEntries.take(_InputLimits.maxEntriesPerSummary).toList();
    final entrySummaries = capped.map((e) {
      try {
        final date = DateTime.parse(e.date);
        final dayName =
            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
        // SECURITY: Only send mood metadata, NOT the actual journal body text
        final tags = e.emotionTags.isEmpty ? 'none' : e.emotionTags.join(', ');
        return '$dayName: mood ${e.moodScore.clamp(1, 10)}/10, energy ${e.energyLevel}, tags: $tags';
      } catch (_) {
        return 'mood ${e.moodScore}/10';
      }
    }).join('\n');

    final avgMood = capped.map((e) => e.moodScore).reduce((a, b) => a + b) /
        capped.length;

    final prompt = '''$_personality

Journal mood data (metadata only, no personal content):
$entrySummaries

Average mood: ${avgMood.toStringAsFixed(1)}/10
Entries: ${capped.length}

Write a warm 3-4 sentence mood summary. Note real patterns. End with something genuinely encouraging.
Flowing prose, no lists. Be honest not just positive.''';

    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15));
      return _cleanResponse(response.text?.trim() ?? 'Could not generate summary.');
    } on TimeoutException {
      return 'Request timed out. Try again!';
    } catch (e) {
      return 'Can\'t generate summary rn — try again later.';
    }
  }

  Future<String> getHabitInsight(
    Map<String, List<bool>> habitCompletions,
  ) async {
    if (!_rateLimiter.check('habitInsight',
        minInterval: const Duration(seconds: 5),
        maxCallsPerMinute: 3)) {
      return 'Getting insights too fast — wait a moment.';
    }

    if (_apiKey.isEmpty) return 'AI unavailable: API key not configured.';

    // SECURITY: Cap habits sent, sanitize names
    final safeData = habitCompletions.entries
        .take(20)
        .map((e) {
          final name = _sanitize(e.key, maxLength: 50);
          final completed = e.value.where((v) => v).length;
          final total = e.value.length;
          return '• $name: $completed/$total days';
        })
        .join('\n');

    final prompt =
        '$_personality\n\n30-day habit completion:\n$safeData\n\nGive 2-3 insights about their patterns. Be real about what\'s working.';

    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15));
      return _cleanResponse(response.text?.trim() ?? 'No response');
    } on TimeoutException {
      return 'Request timed out. Try again!';
    } catch (e) {
      return 'Can\'t reach AI rn — check your connection.';
    }
  }

  // Strip markdown formatting from Gemini responses
  String _cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*', dotAll: true), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*', dotAll: true), r'$1')
        .replaceAll(RegExp(r'#{1,6}\s.*'), '')
        .replaceAll(RegExp(r'`(.+?)`'), r'$1')
        .replaceAll(RegExp(r'^\s*[-*•]\s', multiLine: true), '→ ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}