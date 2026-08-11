import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../data/note_model.dart';
import '../domain/note_notifier.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController titleController;
  late final TextEditingController bodyController;
  late final FocusNode bodyFocus;
  String colorLabel = '#7F77DD'; // default purple (notes accent)
  Note? existingNote;
  bool isEditMode = false;
  bool _isDirty = false;

  // Vibrant colors matching the app's module palette + extra fun ones
  static const List<Map<String, dynamic>> _colorOptions = [
    {'hex': '#7F77DD', 'color': Color(0xFF7F77DD), 'label': 'Purple'},
    {'hex': '#378ADD', 'color': Color(0xFF378ADD), 'label': 'Blue'},
    {'hex': '#1D9E75', 'color': Color(0xFF1D9E75), 'label': 'Teal'},
    {'hex': '#D85A30', 'color': Color(0xFFD85A30), 'label': 'Coral'},
    {'hex': '#EF9F27', 'color': Color(0xFFEF9F27), 'label': 'Amber'},
    {'hex': '#EC4899', 'color': Color(0xFFEC4899), 'label': 'Pink'},
    {'hex': '#06B6D4', 'color': Color(0xFF06B6D4), 'label': 'Cyan'},
    {'hex': '#22C55E', 'color': Color(0xFF22C55E), 'label': 'Green'},
  ];

  Color get _currentColor {
    final match = _colorOptions.firstWhere(
      (c) => c['hex'] == colorLabel,
      orElse: () => _colorOptions.first,
    );
    return match['color'] as Color;
  }

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    bodyController = TextEditingController();
    bodyFocus = FocusNode();

    if (widget.noteId == 'new') {
      isEditMode = true;
    } else {
      _loadExistingNote();
    }

    titleController.addListener(() => setState(() => _isDirty = true));
    bodyController.addListener(() => setState(() => _isDirty = true));
  }

  void _loadExistingNote() {
    final notes = ref.read(notesProvider);
    try {
      existingNote = notes.firstWhere((n) => n.id == widget.noteId);
      titleController.text = existingNote!.title;
      bodyController.text = existingNote!.body;
      colorLabel = existingNote!.colorLabel;
      isEditMode = false;
    } catch (_) {
      isEditMode = true;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (titleController.text.trim().isEmpty &&
        bodyController.text.trim().isEmpty) {
      context.pop();
      return;
    }

    final notifier = ref.read(notesProvider.notifier);

    if (existingNote != null) {
      existingNote!.title = titleController.text.trim();
      existingNote!.body = bodyController.text.trim();
      existingNote!.colorLabel = colorLabel;
      existingNote!.updatedAt = DateTime.now();
      await notifier.updateNote(existingNote!);
    } else {
      final note = Note.create(
        title: titleController.text.trim(),
        body: bodyController.text.trim(),
        colorLabel: colorLabel,
      );
      await notifier.addNote(note);
    }

    if (mounted) {
      setState(() {
        isEditMode = false;
        _isDirty = false;
      });
      if (widget.noteId == 'new') context.pop();
    }
  }

  void _insertBullet() {
    final controller = bodyController;
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) {
      final newText = text.isEmpty ? '• ' : '$text\n• ';
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      bodyFocus.requestFocus();
      return;
    }

    final cursorPos = selection.baseOffset;
    int lineStart = cursorPos;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final currentLine = text.substring(lineStart, cursorPos);
    final alreadyHasBullet = currentLine.startsWith('• ');

    if (alreadyHasBullet) {
      final newText =
          text.substring(0, lineStart) + text.substring(lineStart + 2);
      final newCursor = (cursorPos - 2).clamp(0, newText.length);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    } else {
      final newText = text.substring(0, lineStart) +
          '• ' +
          text.substring(lineStart);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorPos + 2),
      );
    }
    bodyFocus.requestFocus();
  }

  void _insertCheckbox() {
    final controller = bodyController;
    final text = controller.text;
    final sel = controller.selection;
    final pos = sel.isValid ? sel.baseOffset : text.length;
    // Find line start
    int lineStart = pos;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    final newText =
        text.substring(0, lineStart) + '☐ ' + text.substring(lineStart);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart + 2),
    );
    bodyFocus.requestFocus();
  }

  void _onBodyChanged(String value) {
    final text = bodyController.text;
    final selection = bodyController.selection;
    if (!selection.isValid) return;
    final cursorPos = selection.baseOffset;
    if (cursorPos < 1) return;

    if (text[cursorPos - 1] == '\n' && cursorPos >= 3) {
      int prevLineStart = cursorPos - 2;
      while (prevLineStart > 0 && text[prevLineStart - 1] != '\n') {
        prevLineStart--;
      }
      final prevLine = text.substring(prevLineStart, cursorPos - 1);

      if (prevLine == '• ') {
        // Empty bullet — stop the list
        final newText =
            text.substring(0, prevLineStart) + text.substring(cursorPos - 1);
        bodyController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: prevLineStart),
        );
      } else if (prevLine.startsWith('• ')) {
        // Continue bullet list
        final newText =
            text.substring(0, cursorPos) + '• ' + text.substring(cursorPos);
        bodyController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorPos + 2),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete note?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'This note will be permanently deleted.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text('Cancel', style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (existingNote != null) {
        await ref
            .read(notesProvider.notifier)
            .deleteNote(existingNote!.id);
      }
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _currentColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_isDirty && isEditMode) {
              _save();
            } else {
              context.pop();
            }
          },
        ),
        // Accent color indicator in AppBar
        title: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!isEditMode) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: accent),
              onPressed: () {
                setState(() => isEditMode = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  bodyFocus.requestFocus();
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _confirmDelete,
            ),
          ] else
            TextButton(
              onPressed: _save,
              child: Text(
                'Done',
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Left colored border accent strip
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withOpacity(0)],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.md,
                AppSizes.screenPadding,
                AppSizes.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  isEditMode
                      ? TextField(
                          controller: titleController,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Title',
                            hintStyle: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                      : Text(
                          titleController.text.isEmpty
                              ? 'Untitled'
                              : titleController.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                  SizedBox(height: AppSizes.sm),
                  Divider(color: accent.withOpacity(0.3), thickness: 1),
                  SizedBox(height: AppSizes.sm),

                  // Body
                  isEditMode
                      ? TextField(
                          controller: bodyController,
                          focusNode: bodyFocus,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            height: 1.7,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Start writing...',
                            hintStyle: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _onBodyChanged,
                        )
                      : SelectableText(
                          bodyController.text.isEmpty
                              ? 'No content'
                              : bodyController.text,
                          style: TextStyle(
                            color: bodyController.text.isEmpty
                                ? AppColors.textHint
                                : AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.7,
                          ),
                        ),
                ],
              ),
            ),
          ),

          // Toolbar — only in edit mode
          if (isEditMode)
            _NoteToolbar(
              accent: accent,
              colorOptions: _colorOptions,
              selectedHex: colorLabel,
              onColorSelected: (hex) =>
                  setState(() => colorLabel = hex),
              onBullet: _insertBullet,
              onCheckbox: _insertCheckbox,
              onBold: () {
                final sel = bodyController.selection;
                if (!sel.isValid || sel.isCollapsed) return;
                final selected = bodyController.text
                    .substring(sel.start, sel.end);
                final newText = bodyController.text.substring(0, sel.start) +
                    '**$selected**' +
                    bodyController.text.substring(sel.end);
                bodyController.value = TextEditingValue(
                  text: newText,
                  selection:
                      TextSelection.collapsed(offset: sel.end + 4),
                );
              },
              onItalic: () {
                final sel = bodyController.selection;
                if (!sel.isValid || sel.isCollapsed) return;
                final selected = bodyController.text
                    .substring(sel.start, sel.end);
                final newText = bodyController.text.substring(0, sel.start) +
                    '_${selected}_' +
                    bodyController.text.substring(sel.end);
                bodyController.value = TextEditingValue(
                  text: newText,
                  selection:
                      TextSelection.collapsed(offset: sel.end + 2),
                );
              },
            ),
        ],
      ),
    );
  }
}

// Extracted toolbar widget — fixes overflow by using proper layout
class _NoteToolbar extends StatelessWidget {
  const _NoteToolbar({
    required this.accent,
    required this.colorOptions,
    required this.selectedHex,
    required this.onColorSelected,
    required this.onBullet,
    required this.onCheckbox,
    required this.onBold,
    required this.onItalic,
  });

  final Color accent;
  final List<Map<String, dynamic>> colorOptions;
  final String selectedHex;
  final ValueChanged<String> onColorSelected;
  final VoidCallback onBullet;
  final VoidCallback onCheckbox;
  final VoidCallback onBold;
  final VoidCallback onItalic;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      // Two-row toolbar: formatting on top, colors on bottom
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: formatting buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                _ToolbarBtn(
                  child: Text(
                    'B',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: onBold,
                  tooltip: 'Bold (select text first)',
                ),
                const SizedBox(width: 4),
                _ToolbarBtn(
                  child: Text(
                    'I',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  onTap: onItalic,
                  tooltip: 'Italic (select text first)',
                ),
                const SizedBox(width: 4),
                _ToolbarBtn(
                  child: Icon(
                    Icons.format_list_bulleted,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  onTap: onBullet,
                  tooltip: 'Bullet point',
                ),
                const SizedBox(width: 4),
                _ToolbarBtn(
                  child: Icon(
                    Icons.check_box_outline_blank,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  onTap: onCheckbox,
                  tooltip: 'Checkbox',
                ),
                const Spacer(),
                // Active color preview
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  colorOptions
                          .firstWhere(
                            (c) => c['hex'] == selectedHex,
                            orElse: () => colorOptions.first,
                          )['label'] as String,
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Row 2: color picker — horizontal scroll so no overflow
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              children: colorOptions.map((option) {
                final hex = option['hex'] as String;
                final color = option['color'] as Color;
                final label = option['label'] as String;
                final isSelected = selectedHex == hex;

                return Tooltip(
                  message: label,
                  child: GestureDetector(
                    onTap: () => onColorSelected(hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    required this.child,
    required this.onTap,
    this.tooltip = '',
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}