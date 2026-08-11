// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/account_scope.dart';
import '../../badges/data/badge_service.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense_notifier.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String userName = '';
  String userEmoji = '🔥';
  double monthlyBudget = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString(
            AccountScope.scopedPrefKey('userName'),
          ) ??
          '';
      userEmoji = prefs.getString(
            AccountScope.scopedPrefKey('userEmoji'),
          ) ??
          '🔥';
      monthlyBudget =
          ref.read(expenseRepositoryProvider).getMonthlyBudget();
    });
  }

  Future<void> _showEditProfileSheet() async {
    final nameController = TextEditingController(text: userName);
    String tempEmoji = userEmoji;

    final emojis = [
      '🔥', '⚡', '💫', '🎯', '🌸', '🦋', '👾', '🎨',
      '🏔️', '🦊', '🐉', '🌊', '☁️', '🍀', '🎭', '🦁',
      '🌻', '🪐', '💎', '✨',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            width: MediaQuery.of(ctx).size.width,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'DISPLAY NAME',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    hintStyle: TextStyle(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'YOUR EMOJI',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (_, i) {
                    final e = emojis[i];
                    final isSel = tempEmoji == e;
                    return GestureDetector(
                      onTap: () =>
                          setModalState(() => tempEmoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.tasks.withOpacity(0.2)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel
                                ? AppColors.tasks
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final prefs =
                          await SharedPreferences.getInstance();
                      await prefs.setString(
                        AccountScope.scopedPrefKey('userName'),
                        nameController.text.trim(),
                      );
                      await prefs.setString(
                        AccountScope.scopedPrefKey('userEmoji'),
                        tempEmoji,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) {
                        setState(() {
                          userName = nameController.text.trim();
                          userEmoji = tempEmoji;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tasks,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign out?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Your data will still be here when you sign back in.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign out',
                style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await AccountScope.clearCurrentUserEmail();
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final badgeService = ref.watch(badgeServiceProvider);
    final earnedBadges = badgeService.getEarnedBadges();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            // Avatar + edit
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.tasks.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    userEmoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
                GestureDetector(
                  onTap: _showEditProfileSheet,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.tasks,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              userName.isEmpty ? 'TrackIt User' : userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AccountScope.currentUserEmail,
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 13,
              ),
            ),
            SizedBox(height: AppSizes.lg),

            // Badges section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'My Badges',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push('/badges'),
                        child: Text(
                          'See all →',
                          style: TextStyle(
                            color: AppColors.tasks,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (earnedBadges.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '🔒',
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete tasks to unlock badges',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: earnedBadges.take(5).map((badge) {
                          return Container(
                            width: 72,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.habits
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(13),
                                    child: Image.asset(
                                      badge['assetPath'] ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Center(
                                        child: Text(
                                          badge['emoji'] ?? '🏆',
                                          style: const TextStyle(
                                              fontSize: 28),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  badge['name'] ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: AppSizes.md),

            // Settings card
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.account_circle_outlined,
                    iconColor: AppColors.tasks,
                    label: 'Edit Profile',
                    onTap: _showEditProfileSheet,
                  ),
                  Divider(height: 1, color: AppColors.border),
                  _SettingsRow(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.expenses,
                    label: 'Monthly Budget',
                    trailing: Text(
                      monthlyBudget > 0
                          ? '₹${monthlyBudget.toStringAsFixed(0)}'
                          : 'Not set',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () async {
                      final ctrl = TextEditingController(
                        text: monthlyBudget > 0
                            ? monthlyBudget.toStringAsFixed(0)
                            : '',
                      );
                      final newBudget = await showDialog<double>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            'Monthly Budget',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              prefixStyle: TextStyle(
                                color: AppColors.expenses,
                                fontWeight: FontWeight.bold,
                              ),
                              hintText: '0',
                              hintStyle: TextStyle(
                                  color: AppColors.textHint),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: AppColors.border),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: AppColors.expenses),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(),
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: AppColors.textHint)),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(
                                    double.tryParse(ctrl.text.trim()),
                                  ),
                              child: Text('Save',
                                  style: TextStyle(
                                      color: AppColors.expenses,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                      if (newBudget != null && mounted) {
                        await ref
                            .read(expenseRepositoryProvider)
                            .setMonthlyBudget(newBudget);
                        setState(() => monthlyBudget = newBudget);
                      }
                    },
                  ),
                  Divider(height: 1, color: AppColors.border),
                  _SettingsRow(
                    icon: Icons.notifications_outlined,
                    iconColor: AppColors.notes,
                    label: 'Notifications',
                    onTap: () => context.push('/notifications'),
                  ),
                  Divider(height: 1, color: AppColors.border),
                  _SettingsRow(
                    icon: Icons.info_outline,
                    iconColor: AppColors.textHint,
                    label: 'About TrackIt',
                    onTap: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'TrackIt 2.0',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          'Your personal productivity app.\n\nBuilt with Flutter, Riverpod, Hive, and Gemini AI.',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text('Close',
                                style: TextStyle(
                                    color: AppColors.tasks)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSizes.md),

            // Data note
            Text(
              'Data is stored locally on this device',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
              ),
            ),
            SizedBox(height: AppSizes.md),

            // Sign out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSizes.lg),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      trailing: trailing ??
          Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
      onTap: onTap,
    );
  }
}