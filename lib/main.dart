// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/account_scope.dart';
import 'core/utils/notification_service.dart';
import 'features/expenses/data/expense_model.dart';
import 'features/expenses/data/expense_repository.dart';
import 'features/expenses/data/user_settings_model.dart';
import 'features/habits/data/habit_model.dart';
import 'features/habits/data/habit_repository.dart';
import 'features/journal/data/journal_model.dart';
import 'features/journal/data/journal_repository.dart';
import 'features/notes/data/note_model.dart';
import 'features/notes/data/note_repository.dart';
import 'features/tasks/data/task_model.dart';
import 'features/tasks/data/task_repository.dart';
import 'features/auth/data/auth_providers.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/user_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AccountScope.loadFromPrefs();
  await Hive.initFlutter();

  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(JournalEntryAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(UserSettingsAdapter());
  Hive.registerAdapter(HabitAdapter());
  Hive.registerAdapter(HabitLogAdapter());
  Hive.registerAdapter(UserModelAdapter());

  await Hive.openBox<Task>(TaskRepository.boxName);
  await Hive.openBox<Note>(NoteRepository.boxName);
  await Hive.openBox<JournalEntry>(JournalRepository.boxName);
  await Hive.openBox<Expense>(ExpenseRepository.expensesBoxName);
  await Hive.openBox<UserSettings>(ExpenseRepository.settingsBoxName);
  await Hive.openBox<Habit>(HabitRepository.habitsBoxName);
  await Hive.openBox<HabitLog>(HabitRepository.logsBoxName);
  await Hive.openBox<bool>(HabitRepository.medDosesBoxName);
  await Hive.openBox<bool>('badges_box');
  await Hive.openBox<UserModel>(AuthRepository.boxName);

  await NotificationService.init();

  runApp(const ProviderScope(child: TrackItApp()));
}

class TrackItApp extends ConsumerWidget {
  const TrackItApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TrackIt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}