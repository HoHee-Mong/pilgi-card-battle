import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ai/card_generator.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/models/card.dart';
import '../../core/models/source.dart';
import '../../core/theme/tokens.dart';
import '../cards/card_providers.dart';
import 'data/source_repository.dart';
import 'source_providers.dart';

/// 자료 추가 = 파일 고르기 → 옵션(장수·유형) → 바로 Gemini → 카드 저장.
/// 원본은 Storage에 올리지 않는다. `sources`에는 이름·종류·상태·요약만 남는다.
/// 만든 자료 목록을 돌려준다. 취소하면 빈 목록.
Future<List<StudySource>> showAddSourceSheet(
  BuildContext context, {
  required String subjectId,
  required String subjectName,
  required int week,
}) async {
  final result = await showModalBottomSheet<List<StudySource>>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _AddSourceSheet(
      subjectId: subjectId,
      subjectName: subjectName,
      week: week,
    ),
  );
  return result ?? const [];
}

enum _PickKind { camera, gallery, pdf }

enum _Step { pick, options, running }

class _AddSourceSheet extends ConsumerStatefulWidget {
  const _AddSourceSheet({
    required this.subjectId,
    required this.subjectName,
    required this.week,
  });

  final String subjectId;
  final String subjectName;
  final int week;

  @override
  ConsumerState<_AddSourceSheet> createState() => _AddSourceSheetState();
}

class _AddSourceSheetState extends ConsumerState<_AddSourceSheet> {
  _Step _step = _Step.pick;
  bool _picking = false;

  /// 고른 파일. 사진 여러 장은 한 자료로 묶고, PDF는 파일마다 자료 하나.
  List<SourceFile> _files = const [];
  int _count = 10;
  final Set<CardType> _types = {CardType.mcq, CardType.ox, CardType.short};
  String _stage = '';

  // ---- 1단계: 고르기 ----

  Future<List<SourceFile>> _pick(_PickKind kind) async {
    switch (kind) {
      case _PickKind.camera:
      case _PickKind.gallery:
        final picker = ImagePicker();
        final files = kind == _PickKind.gallery
            ? await picker.pickMultiImage(
                imageQuality: 85,
                maxWidth: 2048,
                limit: 10,
              )
            : [
                ?await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                  maxWidth: 2048,
                ),
              ];
        return [
          for (final f in files)
            SourceFile(
              fileName: f.name,
              bytes: await f.readAsBytes(),
              kind: SourceKind.image,
              contentType: _imageMime(f.mimeType, f.name),
            ),
        ];
      case _PickKind.pdf:
        final picked = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
        return [
          for (final f in picked)
            SourceFile(
              fileName: f.name,
              bytes: await f.readAsBytes(),
              kind: SourceKind.pdf,
              contentType: 'application/pdf',
            ),
        ];
    }
  }

  static String _imageMime(String? reported, String name) {
    if (reported != null && reported.startsWith('image/')) return reported;
    return name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  }

  Future<void> _onPick(_PickKind kind) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final files = await _pick(kind);
      if (files.isEmpty) return;
      SourceRepository.checkSizes(files);
      setState(() {
        _files = files;
        _step = _Step.options;
      });
    } on SourceException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('파일을 열지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // ---- 2단계: 옵션 → 3단계: 생성 ----

  /// 사진들은 한 자료, PDF는 파일마다 자료 하나.
  List<List<SourceFile>> _groups() {
    final images = _files.where((f) => f.kind == SourceKind.image).toList();
    final others = _files.where((f) => f.kind != SourceKind.image);
    return [
      if (images.isNotEmpty) images,
      for (final f in others) [f],
    ];
  }

  String _groupName(List<SourceFile> group) {
    if (group.length == 1 && group.single.kind != SourceKind.image) {
      return group.single.fileName;
    }
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final count = group.length > 1 ? ' (${group.length}장)' : '';
    return '필기 ${now.month}.${now.day} $hh$mm$count';
  }

  Future<void> _run() async {
    final uid = ref.read(uidProvider);
    if (uid == null) {
      _toast('로그인 정보를 불러오지 못했어요');
      return;
    }
    final sources = ref.read(sourceRepositoryProvider);
    final cards = ref.read(cardRepositoryProvider);
    final generator = ref.read(cardGeneratorProvider);
    final groups = _groups();
    final created = <StudySource>[];

    setState(() {
      _step = _Step.running;
      _stage = '준비 중';
    });
    final nickname = await ref
        .read(userProfileRepositoryProvider)
        .ensureNickname(uid);

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final progress = groups.length > 1 ? ' (${i + 1}/${groups.length})' : '';
      final source = StudySource(
        id: sources.newId(),
        ownerId: uid,
        subjectId: widget.subjectId,
        week: widget.week,
        kind: group.first.kind,
        fileName: _groupName(group),
        createdAt: DateTime.now(),
      );
      try {
        await sources.create(source);
        if (mounted) setState(() => _stage = 'AI가 문제 만드는 중$progress');
        final result = await generator.generate(
          files: [
            for (final f in group)
              InlineFile(mimeType: f.contentType, bytes: f.bytes),
          ],
          subjectName: widget.subjectName,
          week: widget.week,
          options: CardGenerateOptions(count: _count, types: _types),
        );
        if (mounted) setState(() => _stage = '저장하는 중$progress');
        final now = DateTime.now();
        await cards.createAll([
          for (final g in result.cards)
            QuizCard(
              id: cards.newId(),
              ownerId: uid,
              ownerNickname: nickname,
              subjectId: source.subjectId,
              week: source.week,
              sourceId: source.id,
              sourceLabel: g.sourceHint.isEmpty
                  ? source.label
                  : '${source.label} ${g.sourceHint}',
              type: g.type,
              choices: g.choices,
              question: g.question,
              answer: g.answer,
              explanation: g.explanation,
              concept: g.concept,
              // AI가 만든 카드는 항상 draft. 검수해야 verified가 된다.
              status: CardStatus.draft,
              createdAt: now,
              updatedAt: now,
            ),
        ]);
        await sources.updateStatus(
          source.id,
          SourceStatus.done,
          summary: result.summary.isEmpty ? null : result.summary,
        );
        created.add(source.copyWith(status: SourceStatus.done));
      } on CardGenerationException catch (e) {
        await sources.updateStatus(source.id, SourceStatus.failed);
        _toast('${source.fileName}: ${e.message}');
      } catch (e) {
        await sources.updateStatus(source.id, SourceStatus.failed);
        _toast('${source.fileName}: 카드를 만들지 못했어요 ($e)');
      }
    }
    if (mounted) Navigator.of(context).pop(created);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.page + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(switch (_step) {
                  _Step.pick => '${widget.week}주차 자료 추가',
                  _Step.options => '카드 뽑기',
                  _Step.running => '카드 만드는 중',
                }, style: AppTextStyles.titleM),
              ),
              if (_step != _Step.running)
                IconButton(
                  onPressed: _picking
                      ? null
                      : () => Navigator.of(context).pop(const <StudySource>[]),
                  icon: const Icon(Icons.close),
                  tooltip: '닫기',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(switch (_step) {
            _Step.pick =>
              '필기 사진이나 강의자료 PDF를 고르면 AI가 요약하고 카드를 만들어요. 원본은 저장하지 않아요.',
            _Step.options => _filesLabel(),
            _Step.running => '보통 10~30초 걸려요. 화면을 닫지 마세요.',
          }, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sectionTight),
          switch (_step) {
            _Step.pick => _buildPick(),
            _Step.options => _buildOptions(),
            _Step.running => _buildRunning(),
          },
        ],
      ),
    );
  }

  String _filesLabel() {
    final groups = _groups();
    final names = groups.map(_groupName).join(', ');
    return '$names · ${widget.week}주차';
  }

  Widget _buildPick() {
    if (_picking) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.section),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        _Option(
          icon: Icons.photo_camera_outlined,
          title: '필기 찍기',
          subtitle: '카메라로 노트·칠판 촬영',
          onTap: () => _onPick(_PickKind.camera),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Option(
          icon: Icons.photo_library_outlined,
          title: '갤러리에서 고르기',
          subtitle: '사진 여러 장을 한 자료로 묶어요 (최대 10장)',
          onTap: () => _onPick(_PickKind.gallery),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Option(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF 고르기',
          subtitle: '강의자료 (15MB 이하)',
          onTap: () => _onPick(_PickKind.pdf),
        ),
      ],
    );
  }

  Widget _buildOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('몇 장 만들까요?', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final n in CardGenerateOptions.counts)
              ChoiceChip(
                label: Text('$n장'),
                selected: _count == n,
                onSelected: (_) => setState(() => _count = n),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('문제 유형', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final t in CardType.values)
              FilterChip(
                label: Text(CardGenerator.typeLabel(t)),
                selected: _types.contains(t),
                onSelected: (on) => setState(() {
                  if (on) {
                    _types.add(t);
                  } else if (_types.length > 1) {
                    _types.remove(t);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _run,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text('$_count장 만들기'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _files = const [];
                _step = _Step.pick;
              }),
              child: const Text('다른 파일 고르기'),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                '카드는 초안으로 저장돼요. 검수 후 공유할 수 있어요.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRunning() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stage, style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: const LinearProgressIndicator(
              minHeight: 10,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: 28, color: AppColors.ink),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.heading),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkSub),
            ],
          ),
        ),
      ),
    );
  }
}
