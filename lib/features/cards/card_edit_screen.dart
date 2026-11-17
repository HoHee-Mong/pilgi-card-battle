import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/card_generator.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/models/card.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../subjects/arcade_app_bar.dart';
import '../subjects/arcade_dialog.dart';
import 'card_providers.dart';
import 'card_xp.dart';
import 'card_similarity.dart';
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

  /// 지금 적은 문제와 비슷한 같은 과목 카드. 문제를 고칠 때마다 다시 센다.
  List<SimilarCard> _similar = const [];

  bool get _isEdit => widget.card != null;

  String get _subjectId => widget.card?.subjectId ?? widget.subjectId!;

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
    _question.addListener(_refreshSimilar);
    // 수정 모드는 열자마자 기존 문제로 한 번 센다 (과목 카드가 이미 받아져 있을 때).
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSimilar());
  }

  void _refreshSimilar() {
    final pool =
        ref.read(myCardsProvider((subjectId: _subjectId, week: null))).value ??
        const <QuizCard>[];
    final next = CardSimilarity.find(
      _question.text,
      pool,
      excludeId: widget.card?.id,
    );
    var same = next.length == _similar.length;
    for (var i = 0; same && i < next.length; i++) {
      same = next[i].card.id == _similar[i].card.id;
    }
    if (!same && mounted) setState(() => _similar = next);
  }

  @override
  void dispose() {
    _question.removeListener(_refreshSimilar);
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
    if (_similar.isNotEmpty && !await _confirmSimilar()) return;
    if (!mounted) return;
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
      if (becameVerified(widget.card?.status, status)) {
        unawaited(recordCardsCreated(ref, 1));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('저장하지 못했어요: $e');
    }
  }

  /// 비슷한 문제가 있을 때 저장 전에 한 번 묻는다.
  Future<bool> _confirmSimilar() {
    return showArcadeConfirm(
      context,
      title: '비슷한 문제가 ${_similar.length}개 있어요',
      confirmLabel: '그래도 저장',
      cancelLabel: '다시 볼게요',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in _similar) ...[
            Text(
              s.card.question,
              style: AppTextStyles.bodyS.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${s.card.week}주차 · ${s.card.isVerified ? '검수 완료' : '초안'}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const Text('그래도 따로 저장할까요?', style: AppTextStyles.body),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showArcadeConfirm(
      context,
      title: '카드를 지울까요?',
      confirmLabel: '지우기',
      confirmColor: AppColors.wrong,
    );
    if (!ok) return;
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
    // 과목 카드가 바뀌면(다른 화면에서 추가·삭제) 비슷한 카드 목록도 다시 센다.
    ref.listen(myCardsProvider((subjectId: _subjectId, week: null)), (_, _) {
      _refreshSimilar();
    });
    return Scaffold(
      appBar: ArcadeAppBar(
        trailing: [
          if (_isEdit)
            ArcadeIconButton(
              icon: Icons.delete_outline,
              semanticLabel: '지우기',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.section * 2,
        ),
        children: [
          ArcadeTitle(
            title: _isEdit ? '카드 검수' : '직접 문제 쓰기',
            subtitle: card == null
                ? '${widget.week}주차 · 내가 내는 문제'
                : '출처: ${card.sourceLabel}',
          ),
          if (card != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                StatChip(
                  label: card.isVerified ? '검수 완료' : '초안',
                  color: card.isVerified ? AppColors.lime : AppColors.paper,
                ),
                if (card.roomIds.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StatChip(
                    label: '공유 ${card.roomIds.length}곳',
                    color: AppColors.cyan,
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.section),
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
          if (_similar.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _SimilarBanner(
              similar: _similar,
              onTap: (c) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CardEditScreen.edit(card: c),
                ),
              ),
            ),
          ],
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
          ChunkyButton(
            label: _isEdit ? '검수 완료' : '검수 완료로 저장',
            icon: Icons.check,
            large: true,
            color: AppColors.lime,
            loading: _saving,
            onPressed: () => _save(verify: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          ChunkyButton(
            label: '초안으로 저장',
            color: AppColors.paper,
            onPressed: _saving ? null : () => _save(verify: false),
          ),
          if (card != null && card.isVerified) ...[
            const SizedBox(height: AppSpacing.section),
            ChunkyButton(
              label: card.roomIds.isEmpty
                  ? '방에 공유'
                  : '방에 공유 (${card.roomIds.length}곳에 공유됨)',
              icon: Icons.group_add_outlined,
              color: AppColors.cyan,
              onPressed: _saving ? null : () => _share(card),
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

/// 문제 칸 아래 "비슷한 문제가 있어요" 안내. 누르면 그 카드로 간다.
class _SimilarBanner extends StatelessWidget {
  const _SimilarBanner({required this.similar, required this.onTap});

  final List<SimilarCard> similar;
  final ValueChanged<QuizCard> onTap;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      color: AppColors.sun,
      radius: AppRadius.button,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: AppColors.ink),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '비슷한 문제가 ${similar.length}개 있어요',
                style: AppTextStyles.heading,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final s in similar)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              onTap: () => onTap(s.card),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.card.question,
                        style: AppTextStyles.bodyS,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${s.card.week}주차 · ${(s.score * 100).round()}%',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.ink,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
