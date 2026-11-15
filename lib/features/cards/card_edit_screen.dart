import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/card_generator.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/models/card.dart';
import '../../core/theme/tokens.dart';
import 'card_providers.dart';
import 'share_to_room_sheet.dart';

/// 카드 검수·수정, 또는 직접 문제 쓰기.
/// [card]가 있으면 수정 모드. 없으면 [subjectId]·[week]로 새 카드를 만든다.
class CardEditScreen extends ConsumerStatefulWidget {
  const CardEditScreen._({this.card, this.subjectId, this.week});

  const CardEditScreen.edit({required QuizCard card}) : this._(card: card);

  const CardEditScreen.create({required String subjectId, required int week})
    : this._(subjectId: subjectId, week: week);

  final QuizCard? card;
  final String? subjectId;
  final int? week;

  @override
  ConsumerState<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends ConsumerState<CardEditScreen> {
  late CardType _type;
  late final TextEditingController _question;
  late final List<TextEditingController> _choices;
  late final TextEditingController _answer;
  late final TextEditingController _explanation;
  late final TextEditingController _concept;
  int _mcqAnswerIndex = 0;
  bool _saving = false;

  bool get _isEdit => widget.card != null;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _type = c?.type ?? CardType.mcq;
    _question = TextEditingController(text: c?.question ?? '');
    _choices = List.generate(
      4,
      (i) => TextEditingController(
        text: (c != null && i < c.choices.length) ? c.choices[i] : '',
      ),
    );
    _answer = TextEditingController(
      text: c != null && c.type != CardType.mcq ? c.answer : '',
    );
    _explanation = TextEditingController(text: c?.explanation ?? '');
    _concept = TextEditingController(text: c?.concept ?? '');
    if (c != null && c.type == CardType.mcq) {
      final i = c.choices.indexOf(c.answer);
      _mcqAnswerIndex = i < 0 ? 0 : i;
    }
    if (c != null && c.type == CardType.ox && c.answer != 'O') {
      _answer.text = 'X';
    } else if (_type == CardType.ox && _answer.text.isEmpty) {
      _answer.text = 'O';
    }
  }

  @override
  void dispose() {
    _question.dispose();
    for (final c in _choices) {
      c.dispose();
    }
    _answer.dispose();
    _explanation.dispose();
    _concept.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_question.text.trim().isEmpty) return '문제를 적어 주세요.';
    switch (_type) {
      case CardType.mcq:
        if (_choices.any((c) => c.text.trim().isEmpty)) {
          return '보기 4개를 모두 채워 주세요.';
        }
      case CardType.ox:
        if (_answer.text != 'O' && _answer.text != 'X') return 'O/X를 골라 주세요.';
      case CardType.short:
        if (_answer.text.trim().isEmpty) return '정답을 적어 주세요.';
    }
    return null;
  }

  Future<void> _save({required bool verify}) async {
    if (_saving) return;
    final problem = _validate();
    if (problem != null) {
      _toast(problem);
      return;
    }
    final uid = ref.read(uidProvider);
    if (uid == null) {
      _toast('로그인 정보를 불러오지 못했어요');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(cardRepositoryProvider);
    try {
      final choices = _type == CardType.mcq
          ? [for (final c in _choices) c.text.trim()]
          : const <String>[];
      final answer = switch (_type) {
        CardType.mcq => choices[_mcqAnswerIndex],
        CardType.ox => _answer.text,
        CardType.short => _answer.text.trim(),
      };
      final status = verify ? CardStatus.verified : CardStatus.draft;
      final now = DateTime.now();

      if (_isEdit) {
        final updated = widget.card!.copyWith(
          type: _type,
          question: _question.text.trim(),
          choices: choices,
          answer: answer,
          explanation: _explanation.text.trim(),
          concept: _concept.text.trim(),
          status: status,
          updatedAt: now,
        );
        await repo.update(updated);
      } else {
        final nickname = await ref
            .read(userProfileRepositoryProvider)
            .ensureNickname(uid);
        await repo.create(
          QuizCard(
            id: repo.newId(),
            ownerId: uid,
            ownerNickname: nickname,
            subjectId: widget.subjectId!,
            week: widget.week!,
            sourceId: '',
            sourceLabel: '${widget.week}주차 직접 작성',
            type: _type,
            question: _question.text.trim(),
            choices: choices,
            answer: answer,
            explanation: _explanation.text.trim(),
            concept: _concept.text.trim(),
            status: status,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('저장하지 못했어요: $e');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카드를 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cardRepositoryProvider).delete(widget.card!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _share(QuizCard card) async {
    final roomId = await showShareToRoomSheet(context, card: card);
    if (roomId != null && mounted) Navigator.of(context).pop(true);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '카드 검수' : '직접 문제 쓰기'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: '지우기',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.section,
        ),
        children: [
          if (card != null) ...[
            Row(
              children: [
                _StatusChip(status: card.status),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '출처: ${card.sourceLabel}',
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const Text('유형', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final t in CardType.values)
                ChoiceChip(
                  label: Text(CardGenerator.typeLabel(t)),
                  selected: _type == t,
                  onSelected: (_) => setState(() {
                    _type = t;
                    if (t == CardType.ox && _answer.text != 'X') {
                      _answer.text = 'O';
                    } else if (t == CardType.short &&
                        (_answer.text == 'O' || _answer.text == 'X')) {
                      _answer.text = '';
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('문제', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _question,
            maxLines: null,
            minLines: 2,
            decoration: const InputDecoration(hintText: '문제를 적어 주세요'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('정답', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          ..._answerFields(),
          const SizedBox(height: AppSpacing.lg),
          const Text('해설', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _explanation,
            maxLines: null,
            minLines: 2,
            decoration: const InputDecoration(hintText: '왜 그 답인지 (자료 근거)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('개념 태그', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _concept,
            decoration: const InputDecoration(hintText: '예: TCP 연결 수립'),
          ),
          const SizedBox(height: AppSpacing.section),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _save(verify: true),
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? '검수 완료' : '검수 완료로 저장'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _saving ? null : () => _save(verify: false),
              child: const Text('초안으로 저장'),
            ),
          ),
          if (card != null && card.isVerified) ...[
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _share(card),
                icon: const Icon(Icons.group_add_outlined),
                label: Text(
                  card.roomIds.isEmpty
                      ? '방에 공유'
                      : '방에 공유 (${card.roomIds.length}곳에 공유됨)',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _answerFields() {
    switch (_type) {
      case CardType.mcq:
        return [
          Text('정답인 보기를 눌러 고르세요.', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          RadioGroup<int>(
            groupValue: _mcqAnswerIndex,
            onChanged: (v) => setState(() => _mcqAnswerIndex = v ?? 0),
            child: Column(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  Row(
                    children: [
                      Radio<int>(value: i),
                      Expanded(
                        child: TextField(
                          controller: _choices[i],
                          decoration: InputDecoration(
                            hintText: '보기 ${String.fromCharCode(65 + i)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ];
      case CardType.ox:
        return [
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final v in const ['O', 'X'])
                ChoiceChip(
                  label: Text(v),
                  selected: _answer.text == v,
                  onSelected: (_) => setState(() => _answer.text = v),
                ),
            ],
          ),
        ];
      case CardType.short:
        return [
          TextField(
            controller: _answer,
            decoration: const InputDecoration(hintText: '정답 (단어·짧은 구)'),
          ),
        ];
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CardStatus status;

  @override
  Widget build(BuildContext context) {
    final verified = status == CardStatus.verified;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: verified
            ? AppColors.lime
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        verified ? '검수 완료' : '초안',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
