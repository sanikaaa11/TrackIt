// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/notification_service.dart';
import '../../habits/data/habit_model.dart';
import '../../habits/domain/habit_notifier.dart';
import '../../tasks/data/task_model.dart';
import '../../tasks/domain/task_notifier.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const String _taskRemindersKey = 'pref_task_reminders';
  static const String _habitRemindersKey = 'pref_habit_reminders';
  static const String _weeklyAiKey = 'pref_weekly_ai';
  static const String _journalReminderKey = 'pref_journal_reminder';
  static const String _budgetAlertsKey = 'pref_budget_alerts';
  static const String _habitReminderTimeKey = 'pref_habit_reminder_time';
  static const String _journalReminderTimeKey = 'pref_journal_reminder_time';

  static final int _habitReminderId = NotificationService.habitNotificationId(
    'global_habit_reminder',
  );
  static final int _journalReminderId = 'global_journal_reminder'.hashCode
      .abs();

  bool taskRemindersEnabled = true;
  bool habitRemindersEnabled = true;
  bool weeklyAIEnabled = true;
  bool journalReminderEnabled = false;
  bool budgetAlertsEnabled = true;
  TimeOfDay habitReminderTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay journalReminderTime = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  TimeOfDay _parseTime(String? value, TimeOfDay fallback) {
    if (value == null || value.isEmpty) return fallback;

    final parts = value.split(':');
    if (parts.length != 2) return fallback;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _displayTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  int _taskNotificationId(Task task) {
    return NotificationService.taskNotificationId(task.id);
  }

  bool _shouldTrackTask(Task task) {
    return task.dueDate != null && !task.isComplete;
  }

  Future<void> _loadPreferences() async {
    final prefs = await _prefs;

    if (!mounted) return;

    setState(() {
      taskRemindersEnabled = prefs.getBool(_taskRemindersKey) ?? true;
      habitRemindersEnabled = prefs.getBool(_habitRemindersKey) ?? true;
      weeklyAIEnabled = prefs.getBool(_weeklyAiKey) ?? true;
      journalReminderEnabled = prefs.getBool(_journalReminderKey) ?? false;
      budgetAlertsEnabled = prefs.getBool(_budgetAlertsKey) ?? true;
      habitReminderTime = _parseTime(
        prefs.getString(_habitReminderTimeKey),
        habitReminderTime,
      );
      journalReminderTime = _parseTime(
        prefs.getString(_journalReminderTimeKey),
        journalReminderTime,
      );
    });

    await _syncScheduledNotifications();
  }

  Future<void> _syncScheduledNotifications() async {
    if (taskRemindersEnabled) {
      await _scheduleTaskNotifications();
    } else {
      await _cancelTaskNotifications();
    }

    if (habitRemindersEnabled) {
      await _scheduleHabitNotification();
    } else {
      await NotificationService.cancelHabitReminder(_habitReminderId);
    }

    if (journalReminderEnabled) {
      await _scheduleJournalNotification();
    } else {
      await NotificationService.cancelJournalReminder(_journalReminderId);
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }

  Future<void> _saveTime(String key, TimeOfDay value) async {
    final prefs = await _prefs;
    await prefs.setString(key, _formatTime(value));
  }

  Future<void> _scheduleTaskNotifications() async {
    final tasks = ref.read(tasksProvider);
    for (final task in tasks.where(_shouldTrackTask)) {
      await NotificationService.scheduleTaskNotification(
        id: _taskNotificationId(task),
        taskTitle: task.title,
        dueDate: task.dueDate!,
      );
    }
  }

  Future<void> _cancelTaskNotifications() async {
    final tasks = ref.read(tasksProvider);
    for (final task in tasks.where(_shouldTrackTask)) {
      await NotificationService.cancelTaskNotification(
        _taskNotificationId(task),
      );
    }
  }

  Future<void> _scheduleHabitNotification() async {
    await NotificationService.scheduleHabitReminder(
      id: _habitReminderId,
      habitName: 'Habit check-in',
      reminderTime: habitReminderTime,
    );
  }

  Future<void> _scheduleJournalNotification() async {
    await NotificationService.scheduleJournalReminder(
      id: _journalReminderId,
      reminderTime: journalReminderTime,
    );
  }

  Future<void> _toggleTaskReminders(bool value) async {
    setState(() => taskRemindersEnabled = value);
    await _saveBool(_taskRemindersKey, value);

    if (value) {
      await _scheduleTaskNotifications();
    } else {
      await _cancelTaskNotifications();
    }
  }

  Future<void> _toggleHabitReminders(bool value) async {
    setState(() => habitRemindersEnabled = value);
    await _saveBool(_habitRemindersKey, value);

    if (value) {
      await _scheduleHabitNotification();
    } else {
      await NotificationService.cancelHabitReminder(_habitReminderId);
    }
  }

  Future<void> _toggleWeeklyAI(bool value) async {
    setState(() => weeklyAIEnabled = value);
    await _saveBool(_weeklyAiKey, value);
  }

  Future<void> _toggleJournalReminder(bool value) async {
    setState(() => journalReminderEnabled = value);
    await _saveBool(_journalReminderKey, value);

    if (value) {
      await _scheduleJournalNotification();
    } else {
      await NotificationService.cancelJournalReminder(_journalReminderId);
    }
  }

  Future<void> _toggleBudgetAlerts(bool value) async {
    setState(() => budgetAlertsEnabled = value);
    await _saveBool(_budgetAlertsKey, value);
  }

  Future<void> _pickHabitReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: habitReminderTime,
    );

    if (picked == null) return;

    setState(() => habitReminderTime = picked);
    await _saveTime(_habitReminderTimeKey, picked);

    if (habitRemindersEnabled) {
      await _scheduleHabitNotification();
    }
  }

  Future<void> _pickJournalReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: journalReminderTime,
    );

    if (picked == null) return;

    setState(() => journalReminderTime = picked);
    await _saveTime(_journalReminderTimeKey, picked);

    if (journalReminderEnabled) {
      await _scheduleJournalNotification();
    }
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.expenses,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildTimeTile({
    required String title,
    required String subtitle,
    required TimeOfDay value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Text(
          _displayTime(value),
          style: TextStyle(
            color: AppColors.expenses,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _buildSwitchTile(
            title: 'Task reminders',
            subtitle: 'Notify me when tasks are due',
            value: taskRemindersEnabled,
            onChanged: _toggleTaskReminders,
          ),
          _buildSwitchTile(
            title: 'Habit reminders',
            subtitle: 'Daily nudge to keep your streak going',
            value: habitRemindersEnabled,
            onChanged: _toggleHabitReminders,
          ),
          _buildTimeTile(
            title: 'Habit reminder time',
            subtitle: 'When the habit reminder is sent',
            value: habitReminderTime,
            onTap: _pickHabitReminderTime,
          ),
          _buildSwitchTile(
            title: 'Weekly AI',
            subtitle: 'Show weekly AI insights and prompts',
            value: weeklyAIEnabled,
            onChanged: _toggleWeeklyAI,
          ),
          _buildSwitchTile(
            title: 'Journal reminder',
            subtitle: 'Daily reflection reminder',
            value: journalReminderEnabled,
            onChanged: _toggleJournalReminder,
          ),
          _buildTimeTile(
            title: 'Journal reminder time',
            subtitle: 'When the journal reminder is sent',
            value: journalReminderTime,
            onTap: _pickJournalReminderTime,
          ),
          _buildSwitchTile(
            title: 'Budget alerts',
            subtitle: 'Get alerted about your spending',
            value: budgetAlertsEnabled,
            onChanged: _toggleBudgetAlerts,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Notification preferences are saved locally on this device.',
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
