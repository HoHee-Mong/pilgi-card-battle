import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import 'subject_providers.dart';

/// 과목 만들기 / 수정 바텀시트. [subject]가 있으면 수정 모드.
/// 저장된 과목을 돌려준다. 취소하면 null.
Future<Subject?> showSubjectFormSheet(
  BuildContext context, {
  Subject? subject,
}) {
  return showModalBottomSheet<Subject>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _SubjectFormSheet(subject: subject),
  );
}

class _SubjectFormSheet extends ConsumerStatefulWidget {
  const _SubjectFormSheet({this.subject});

  final Subject? subject;

  @override
  ConsumerState<_SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends ConsumerState<_SubjectFormSheet> {
  late final TextEditingController _name;
  DateTime? _examDate;
  bool _saving = false;

  bool get _isEdit => widget.subject != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.subject?.name ?? '');
    _examDate = widget.subject?.examDate;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: '시험일',
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    final uid = ref.read(uidProvider);
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 정보를 불러오지 못했어요')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(subjectRepositoryProvider);
    try {
      Subject saved;
      if (_isEdit) {
        saved = widget.subject!.copyWith(name: name, examDate: _examDate);
        // copyWith는 null로 되돌릴 수 없어 시험일 해제는 따로 만든다.
        if (_examDate == null) {
          saved = Subject(
            id: saved.id,
            ownerId: saved.ownerId,
            name: name,
            createdAt: saved.createdAt,
          );
        }
        await repo.update(saved);
      } else {
        saved = await repo.create(uid: uid, name: name, examDate: _examDate);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장하지 못했어요: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canSave = _name.text.trim().isNotEmpty && !_saving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.page + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEdit ? '과목 수정' : '새 과목', style: AppTextStyles.titleM),
          const SizedBox(height: AppSpacing.sectionTight),
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(hintText: '과목 이름 (예: 컴퓨터네트워크)'),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateRow(
            date: _examDate,
            onPick: _pickDate,
            onClear: _examDate == null
                ? null
                : () => setState(() => _examDate = null),
          ),
          const SizedBox(height: AppSpacing.section),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: canSave ? _save : null,
              child: Text(_isEdit ? '저장' : '만들기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onPick, this.onClear});

  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? '시험일 (선택)'
        : '시험일 ${date!.year}.${date!.month}.${date!.day}';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.event_outlined, size: 20),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: date == null ? AppColors.inkSub : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: onClear,
            tooltip: '시험일 지우기',
            icon: const Icon(Icons.close),
          ),
        ],
      ],
    );
  }
}
