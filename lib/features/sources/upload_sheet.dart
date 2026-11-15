import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/source.dart';
import '../../core/theme/tokens.dart';
import 'data/source_repository.dart';
import 'source_providers.dart';

/// 자료 올리기 바텀시트: 촬영 / 갤러리 / PDF.
/// 올린 자료 목록을 돌려준다. 취소하면 빈 목록.
Future<List<StudySource>> showUploadSheet(
  BuildContext context, {
  required String subjectId,
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
    builder: (_) => _UploadSheet(subjectId: subjectId, week: week),
  );
  return result ?? const [];
}

enum _PickKind { camera, gallery, pdf }

class _UploadSheet extends ConsumerStatefulWidget {
  const _UploadSheet({required this.subjectId, required this.week});

  final String subjectId;
  final int week;

  @override
  ConsumerState<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<_UploadSheet> {
  /// null이면 아직 고르는 중
  String? _stage;
  double _progress = 0;
  int _done = 0;
  int _total = 0;

  bool get _busy => _stage != null;

  Future<List<UploadFile>> _pick(_PickKind kind) async {
    switch (kind) {
      case _PickKind.camera:
      case _PickKind.gallery:
        final picker = ImagePicker();
        final source = kind == _PickKind.camera
            ? ImageSource.camera
            : ImageSource.gallery;
        final files = kind == _PickKind.gallery
            ? await picker.pickMultiImage(
                imageQuality: 85,
                maxWidth: 2048,
                limit: 10,
              )
            : [
                ?await picker.pickImage(
                  source: source,
                  imageQuality: 85,
                  maxWidth: 2048,
                ),
              ];
        return [
          for (final f in files)
            UploadFile(
              fileName: _imageName(f.name),
              bytes: await f.readAsBytes(),
              kind: SourceKind.image,
              contentType: f.mimeType ?? 'image/jpeg',
            ),
        ];
      case _PickKind.pdf:
        final picked = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
        return [
          for (final f in picked)
            UploadFile(
              fileName: f.name,
              bytes: await f.readAsBytes(),
              kind: SourceKind.pdf,
              contentType: 'application/pdf',
            ),
        ];
    }
  }

  /// 카메라 사진 이름은 의미 없는 문자열이라 날짜 기반으로 바꾼다.
  String _imageName(String original) {
    final lower = original.toLowerCase();
    if (lower.startsWith('image_picker') || lower.startsWith('scaled_')) {
      final now = DateTime.now();
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      return '필기 ${now.month}.${now.day} $hh$mm.jpg';
    }
    return original;
  }

  Future<void> _run(_PickKind kind) async {
    if (_busy) return;
    final uid = ref.read(uidProvider);
    if (uid == null) {
      _toast('로그인 정보를 불러오지 못했어요');
      return;
    }

    List<UploadFile> files;
    try {
      setState(() => _stage = '파일 고르는 중');
      files = await _pick(kind);
    } catch (e) {
      if (!mounted) return;
      setState(() => _stage = null);
      _toast('파일을 열지 못했어요: $e');
      return;
    }
    if (files.isEmpty) {
      if (mounted) setState(() => _stage = null);
      return;
    }

    final repo = ref.read(sourceRepositoryProvider);
    final uploaded = <StudySource>[];
    setState(() {
      _total = files.length;
      _done = 0;
      _progress = 0;
      _stage = '올리는 중';
    });
    for (final file in files) {
      try {
        final s = await repo.upload(
          uid: uid,
          subjectId: widget.subjectId,
          week: widget.week,
          file: file,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        uploaded.add(s);
      } on SourceException catch (e) {
        _toast('${file.fileName}: ${e.message}');
      } catch (e) {
        _toast('${file.fileName}: 올리지 못했어요 ($e)');
      }
      if (mounted) setState(() => _done++);
    }
    if (mounted) Navigator.of(context).pop(uploaded);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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
                child: Text(
                  '${widget.week}주차 자료 올리기',
                  style: AppTextStyles.titleM,
                ),
              ),
              if (!_busy)
                IconButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const <StudySource>[]),
                  icon: const Icon(Icons.close),
                  tooltip: '닫기',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '필기 사진이나 강의자료 PDF를 올리면 AI가 요약하고 카드를 만들어요.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sectionTight),
          if (_busy)
            _Progress(
              stage: _stage!,
              progress: _progress,
              done: _done,
              total: _total,
            )
          else ...[
            _Option(
              icon: Icons.photo_camera_outlined,
              title: '필기 찍기',
              subtitle: '카메라로 노트·칠판 촬영',
              onTap: () => _run(_PickKind.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Option(
              icon: Icons.photo_library_outlined,
              title: '갤러리에서 고르기',
              subtitle: '사진 여러 장 한 번에',
              onTap: () => _run(_PickKind.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Option(
              icon: Icons.picture_as_pdf_outlined,
              title: 'PDF 올리기',
              subtitle: '강의자료 (15MB 이하)',
              onTap: () => _run(_PickKind.pdf),
            ),
          ],
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

class _Progress extends StatelessWidget {
  const _Progress({
    required this.stage,
    required this.progress,
    required this.done,
    required this.total,
  });

  final String stage;
  final double progress;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final picking = total == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            picking
                ? stage
                : '$stage ${done + 1 > total ? total : done + 1}/$total',
            style: AppTextStyles.heading,
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: LinearProgressIndicator(
              value: picking ? null : progress,
              minHeight: 10,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
