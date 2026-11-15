import 'package:flutter/material.dart';

import '../../core/models/source.dart';
import '../../core/theme/tokens.dart';

IconData sourceIcon(SourceKind kind) => switch (kind) {
  SourceKind.image => Icons.image_outlined,
  SourceKind.pdf => Icons.picture_as_pdf_outlined,
  SourceKind.audio => Icons.mic_none_outlined,
};

String sourceStatusLabel(SourceStatus status) => switch (status) {
  SourceStatus.uploaded => '올림',
  SourceStatus.processing => '분석 중',
  SourceStatus.done => '카드 완료',
  SourceStatus.failed => '실패',
};

/// 자료 목록 한 줄. 탭하면 상세로.
class SourceTile extends StatelessWidget {
  const SourceTile({super.key, required this.source, required this.onTap});

  final StudySource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(sourceIcon(source.kind), size: 26, color: AppColors.ink),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.fileName,
                      style: AppTextStyles.bodyS.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SourceStatusChip(status: source.status),
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

class SourceStatusChip extends StatelessWidget {
  const SourceStatusChip({super.key, required this.status});

  final SourceStatus status;

  @override
  Widget build(BuildContext context) {
    final highlight = status == SourceStatus.done;
    final failed = status == SourceStatus.failed;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.lime
            : failed
            ? AppColors.wrong
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        sourceStatusLabel(status),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
