import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../domain/note_notifier.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Map hex strings to actual Color objects for display
  Color _hexToColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final notes = ref.watch(filteredNotesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  border: InputBorder.none,
                ),
                onChanged: (q) =>
                    ref.read(searchQueryProvider.notifier).state = q,
              )
            : const Text(
                'Notes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: AppColors.notes,
            ),
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              }
            },
          ),
        ],
      ),
      body: notes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    color: AppColors.textHint,
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    searchQuery.isEmpty
                        ? 'Start capturing thoughts'
                        : 'No notes match "$searchQuery"',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  if (searchQuery.isEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tap + to create your first note',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.all(AppSizes.md),
              child: _NotesGrid(
                notes: notes,
                hexToColor: _hexToColor,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.notes,
        onPressed: () => context.push('/notes/edit/new'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _NotesGrid extends ConsumerWidget {
  const _NotesGrid({
    required this.notes,
    required this.hexToColor,
  });

  final dynamic notes;
  final Color Function(String) hexToColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Simple 2-column staggered layout using a CustomScrollView
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final accentColor = hexToColor(note.colorLabel);

        return GestureDetector(
          onTap: () => context.push('/notes/edit/${note.id}'),
          onLongPress: () => _showNoteOptions(context, ref, note),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border(
                left: BorderSide(
                  color: accentColor,
                  width: 3,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pin indicator
                  if (note.isPinned)
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        Icons.push_pin,
                        color: accentColor,
                        size: 14,
                      ),
                    ),

                  // Title
                  Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Body preview
                  Expanded(
                    child: Text(
                      note.body.isEmpty ? 'No content' : note.body,
                      style: TextStyle(
                        color: note.body.isEmpty
                            ? AppColors.textHint
                            : AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date + color dot
                  Row(
                    children: [
                      Text(
                        _formatDate(note.updatedAt),
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showNoteOptions(BuildContext context, WidgetRef ref, dynamic note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.notes.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  note.isPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin,
                  color: AppColors.notes,
                  size: 20,
                ),
              ),
              title: Text(
                note.isPinned ? 'Unpin note' : 'Pin note',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                ref.read(notesProvider.notifier).togglePin(note.id);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              title: Text(
                'Delete note',
                style: TextStyle(color: AppColors.error, fontSize: 15),
              ),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Delete note?',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    content: Text(
                      'This will be permanently deleted.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel',
                            style: TextStyle(color: AppColors.textHint)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('Delete',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  ref.read(notesProvider.notifier).deleteNote(note.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}