import 'package:flutter/material.dart';

import '../../core/ai/card_generator.dart';
import '../../core/models/card.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/stat_chip.dart';
import '../../fx/haptics.dart';
import 'solo_model.dart';

/// 문제 한 장 풀기 (시안 game-exam의 문제 카드 + A/B/C/D 블록). 어두운(ink) 배경용.
///
/// 답을 고르면 바로 채점해 정답은 lime, 내가 고른 오답은 wrong으로 칠하고
/// 해설과 "다음" 버튼을 보여 준다. 카드가 바뀌면 `key: ValueKey(card.id)`로 다시 만든다.
/// 혼자 풀기와 모의고사 보스전이 같이 쓴다.
class QuizQuestionView extends StatefulWidget {
  const QuizQuestionView({
    super.key,
    required this.card,
    required this.onAnswered,
    required this.onNext,
    this.nextLabel = '다음 문제',
    this.badge,
    this.instantFeedback = true,
  });

  final QuizCard card;

  /// 채점 직후 (정답 여부, 내가 쓴 답)
  final void Function(bool correct, String answer) onAnswered;
  final VoidCallback onNext;
  final String nextLabel;

  /// 문제 카드 위 작은 알약 (예: "7명이 나올 것 같대요")
  final Widget? badge;

  /// false면 고르자마자 채점·해설 없이 바로 [onNext] (모의고사 일괄 채점용)
  final bool instantFeedback;

  @override
  State<QuizQuestionView> createState() => _QuizQuestionViewState();
}

class _QuizQuestionViewState extends State<QuizQuestionView> {
  String? _answer;
  bool _correct = false;
  final _short = TextEditingController();

  bool get _revealed => _answer != null;

  @override
  void dispose() {
    _short.dispose();
    super.dispose();
  }

  void _submit(String answer) {
    if (_revealed) return;
    final correct = isCorrectAnswer(widget.card, answer);
    if (correct) {
      Haptics.light();
    } else {
      Haptics.medium();
    }
    setState(() {
      _answer = answer;
      _correct = correct;
    });
    widget.onAnswered(correct, answer);
    if (!widget.instantFeedback) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChunkyCard(
          shadowColor: AppColors.grape,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatChip(
                    label: CardGenerator.typeLabel(card.type),
                    color: AppColors.paper,
                  ),
                  if (widget.badge != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: widget.badge!),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(card.question, style: AppTextStyles.titleM),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        ...switch (card.type) {
          CardType.mcq => [
            for (final (i, choice) in card.choices.indexed) ...[
              QuizChoiceBlock(
                letter: String.fromCharCode(65 + i),
                text: choice,
                state: _stateFor(choice),
                onTap: _revealed ? null : () => _submit(choice),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          CardType.ox => [
            Row(
              children: [
                for (final v in const ['O', 'X']) ...[
                  Expanded(
                    child: QuizChoiceBlock(
                      letter: v,
                      text: v == 'O' ? '맞다' : '틀리다',
                      state: _stateFor(v),
                      onTap: _revealed ? null : () => _submit(v),
                    ),
                  ),
                  if (v == 'O') const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ],
          CardType.short => [
            if (!_revealed) ...[
              TextField(
                controller: _short,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _submit(v.trim());
                },
                decoration: const InputDecoration(hintText: '정답을 적어 주세요'),
              ),
              const SizedBox(height: AppSpacing.sm),
              ChunkyButton(
                label: '제출',
                color: AppColors.lime,
                onPressed: () {
                  final v = _short.text.trim();
                  if (v.isNotEmpty) _submit(v);
                },
              ),
            ] else ...[
              QuizChoiceBlock(
                letter: '답',
                text: card.answer,
                state: QuizChoiceState.correct,
              ),
              if (!_correct) ...[
                const SizedBox(height: AppSpacing.sm),
                QuizChoiceBlock(
                  letter: '나',
                  text: _answer!,
                  state: QuizChoiceState.wrong,
                ),
              ],
            ],
          ],
        },
        if (_revealed && widget.instantFeedback) ...[
          const SizedBox(height: AppSpacing.section),
          Row(
            children: [
              Expanded(
                child: OutlinedText(
                  _correct ? '적중!' : '빗나감',
                  color: _correct ? AppColors.lime : AppColors.pink,
                ),
              ),
              SizedBox(
                width: 160,
                child: ChunkyButton(
                  label: widget.nextLabel,
                  color: AppColors.lime,
                  shadowColor: AppColors.grape,
                  onPressed: widget.onNext,
                ),
              ),
            ],
          ),
          if (card.explanation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ChunkyCard(
              color: AppColors.paper,
              radius: AppRadius.button,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('해설', style: AppTextStyles.heading),
                  const SizedBox(height: AppSpacing.xs),
                  Text(card.explanation, style: AppTextStyles.bodyS),
                  if (card.sourceLabel.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '출처: ${card.sourceLabel}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  QuizChoiceState _stateFor(String choice) {
    if (!_revealed || !widget.instantFeedback) {
      return _answer == choice ? QuizChoiceState.picked : QuizChoiceState.idle;
    }
    if (choice == widget.card.answer) return QuizChoiceState.correct;
    if (choice == _answer) return QuizChoiceState.wrong;
    return QuizChoiceState.dim;
  }
}

/// 보기 블록 상태. [picked]는 채점 전 "내가 고른 답"(모의고사).
enum QuizChoiceState { idle, picked, correct, wrong, dim }

/// 보기 블록: 왼쪽 글자 네모 + 본문. 정답 lime / 오답 wrong / 나머지 흐림.
class QuizChoiceBlock extends StatelessWidget {
  const QuizChoiceBlock({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    this.onTap,
  });

  final String letter;
  final String text;
  final QuizChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      QuizChoiceState.correct => AppColors.lime,
      QuizChoiceState.wrong => AppColors.wrong,
      QuizChoiceState.picked => AppColors.cyan,
      QuizChoiceState.idle || QuizChoiceState.dim => AppColors.paper,
    };
    final tag = switch (state) {
      QuizChoiceState.correct => '정답',
      QuizChoiceState.wrong => '내 답',
      _ => null,
    };
    return Opacity(
      opacity: state == QuizChoiceState.dim ? 0.55 : 1,
      child: ChunkyCard(
        onTap: onTap,
        color: color,
        radius: AppRadius.button,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: Text(letter, style: AppTextStyles.chip),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(text, style: AppTextStyles.body)),
            if (tag != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(tag, style: AppTextStyles.chip),
            ],
          ],
        ),
      ),
    );
  }
}
