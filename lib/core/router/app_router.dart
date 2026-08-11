import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// ignore: unused_import
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/account_scope.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/badges/presentation/badges_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/expenses/presentation/add_expense_screen.dart';
import '../../features/expenses/presentation/expense_history_screen.dart';
import '../../features/expenses/presentation/expense_home_screen.dart';
import '../../features/expenses/presentation/expense_report_screen.dart';
import '../../features/habits/presentation/add_habit_screen.dart';
import '../../features/habits/presentation/habit_detail_screen.dart';
import '../../features/habits/presentation/habits_screen.dart';
import '../../features/journal/presentation/journal_entry_screen.dart';
import '../../features/journal/presentation/journal_list_screen.dart';
import '../../features/notes/presentation/note_editor_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/onboarding/presentation/onboarding_budget_screen.dart';
import '../../features/onboarding/presentation/onboarding_ready_screen.dart';
import '../../features/onboarding/presentation/onboarding_vibe_screen.dart';
import '../../features/onboarding/presentation/onboarding_welcome_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/notifications_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/tasks/presentation/add_task_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../shared/bottom_nav_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      // Only redirect from root
      if (state.fullPath == '/splash') return null;
      if (state.fullPath == '/auth') return null;
      if (state.fullPath?.startsWith('/onboarding') ?? false) return null;

      await AccountScope.loadFromPrefs();
      if (!AccountScope.hasActiveUser) {
        return '/auth';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/onboarding/welcome',
        builder: (context, state) => const OnboardingWelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/vibe',
        builder: (context, state) => const OnboardingVibeScreen(),
      ),
      GoRoute(
        path: '/onboarding/budget',
        builder: (context, state) => const OnboardingBudgetScreen(),
      ),
      GoRoute(
        path: '/onboarding/ready',
        builder: (context, state) => const OnboardingReadyScreen(),
      ),
      StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavShell(
        navigationShell: navigationShell,
      ),
    );
  },
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const DashboardScreen(),
        ),
      ],
    ),

    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/tasks',
          builder: (context, state) => const TasksScreen(),
        ),
      ],
    ),

    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/notes',
          builder: (context, state) => const NotesScreen(),
        ),
      ],
    ),

    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/expenses',
          builder: (context, state) => const ExpenseHomeScreen(),
        ),
      ],
    ),

    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/habits',
          builder: (context, state) => const HabitsScreen(),
        ),
      ],
    ),
  ],
),
      GoRoute(
        path: '/tasks/add',
        builder: (context, state) => const AddTaskScreen(),
      ),
      GoRoute(
        path: '/notes/edit/:id',
        builder: (context, state) =>
            NoteEditorScreen(noteId: state.pathParameters['id'] ?? 'new'),
      ),
      GoRoute(
        path: '/journal',
        builder: (context, state) => const JournalListScreen(),
      ),
      GoRoute(
        path: '/journal/entry/:date',
        builder: (context, state) =>
            JournalEntryScreen(date: state.pathParameters['date'] ?? ''),
      ),
      GoRoute(
        path: '/expenses/add',
        builder: (context, state) =>
            AddExpenseScreen(extra: state.extra as Map<String, dynamic>?),
      ),
      GoRoute(
        path: '/expenses/report',
        builder: (context, state) => const ExpenseReportScreen(),
      ),
      GoRoute(
        path: '/expenses/history',
        builder: (context, state) => const ExpenseHistoryScreen(),
      ),
      GoRoute(
  path: '/habits/add',
  builder: (context, state) => const AddHabitScreen(),
),
      GoRoute(
        path: '/habits/detail/:id',
        builder: (context, state) =>
            HabitDetailScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/badges',
        builder: (context, state) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});