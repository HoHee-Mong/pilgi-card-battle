import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/attempt.dart';
import '../../core/models/card.dart';
import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/stat_chip.dart';
import '../subjects/arcade_app_bar.dart';
import '../subjects/arcade_dialog.dart';
import 'quiz_question_view.dart';
import 'solo_model.dart';
import 'solo_providers.dart';
import 'solo_result_screen.dart';

/// 혼자 풀기 진행 화면 (ink 배경). 한 문제씩 풀고 바로 채점, 끝나면 결과로.
class SoloPlayScreen extends ConsumerStatefulWidget {
  const SoloPlayScreen({super.key, required this.subject, required this.cards});

  final Subject subject;
  final List<QuizCard> cards;

  @override
  ConsumerState<SoloPlayScreen> createState() => _SoloPlayScreenState();
}

class _SoloPlayScreenState extends ConsumerState<SoloPlayScreen> {
  int _index = 0;
  final List<QuizResult> _results = [];
  bool _finishing = false;

  QuizCard get _card => widget.cards[_index];
  int get _correct => countCorrect(_results);

  void _onAnswered(bool correct, String answer) {
    _results.add((card: _card, answer: answer, correct: correct));
    setState(() {});
  }

  Future<void> _next() async {
    if (_index + 1 < widget.cards.length) {
      setState(() => _index++);
      return;
    }
    await _finish();
  }

  /// 기록을 저장하고 결과 화면으로. 중간에 나가도 푼 만큼은 저장한다.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final uid = ref.read(uidProvider);
    if (uid != null && _results.isNotEmpty) {
      final repo = ref.read(attemptRepositoryProvider);
      final now = DateTime.now();
      try {
        await repo.saveAttempts(uid, [
          for (final r in _results)
            Attempt(
              id: repo.newId(uid),
              cardId: r.card.id,
              subjectId: widget.subject.id,
              concept: r.card.concept,
              correct: r.correct,
              mode: AttemptMode.solo,
              at: now,
            ),
        ]);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('기록을 저장하지 못했어요: $e')));
        }
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<String>(
        builder: (_) => SoloResultScreen(
          subject: widget.subject,
          results: List.unmodifiable(_results),
          total: widget.cards.length,
        ),
      ),
    );
  }

  Future<void> _quit() async {
    final ok = await showArcadeConfirm(
      context,
      title: '그만 풀까요?',
      message: _results.isEmpty
          ? '아직 푼 문제가 없어요.'
          : '지금까지 푼 ${_results.length}문제는 기록돼요.',
      confirmLabel: '그만두기',
      cancelLabel: '계속 풀기',
      confirmColor: AppColors.wrong,
    );
    if (!ok || !mounted) return;
    if (_results.isEmpty) {
      Navigator.of(context).pop();
    } else {
      await _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.cards.length;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: ArcadeAppBar(
        backgroundColor: AppColors.ink,
        leading: ArcadeIconButton(
          icon: Icons.close,
          semanticLabel: '그만두기',
          onPressed: _quit,
        ),
        trailing: [StatChip(label: '적중 $_correct', color: AppColors.sun)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.section * 2,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.subject.name,
                  style: AppTextStyles.label.copyWith(color: AppColors.pink),
                ),
              ),
              Text(
                '${_index + 1} / $total',
                style: AppTextStyles.titleM.copyWith(color: AppColors.paper),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Progress(done: _index, total: total),
          const SizedBox(height: AppSpacing.section),
          QuizQuestionView(
            key: ValueKey(_card.id),
            card: _card,
            onAnswered: _onAnswered,
            onNext: _next,
            nextLabel: _index + 1 < total ? '다음 문제' : '결과 보기',
          ),
        ],
      ),
    );
  }
}

/// 진행 막대 (pink, ink 테두리).
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.grape,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.paper, width: AppBlock.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: AppMotion.hpBar,
          curve: Curves.easeOut,
          widthFactor: ratio,
          child: const ColoredBox(
            color: AppColors.pink,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
