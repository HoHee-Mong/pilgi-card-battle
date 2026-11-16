import 'package:flutter/material.dart';

import '../../core/models/source.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';

IconData sourceIcon(SourceKind kind) => switch (kind) {
  SourceKind.image => Icons.image_outlined,
  SourceKind.pdf => Icons.picture_as_pdf_outlined,
  SourceKind.audio => Icons.mic_none_outlined,
};

String sourceStatusLabel(SourceStatus status) => switch (status) {
  SourceStatus.uploaded => '대기',
  SourceStatus.processing => '분석 중',
  SourceStatus.done => '카드 완료',
  SourceStatus.failed => '실패',
};

Color sourceStatusColor(SourceStatus status) => switch (status) {
  SourceStatus.done => AppColors.lime,
  SourceStatus.failed => AppColors.wrong,
  SourceStatus.processing => AppColors.sun,
  SourceStatus.uploaded => AppColors.cream,
};

/// 자료 목록 한 줄 블록. 탭하면 상세로.
class SourceTile extends StatelessWidget {
  const SourceTile({super.key, required this.source, required this.onTap});

  final StudySource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      onTap: onTap,
      radius: AppRadius.button,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _IconBlock(icon: sourceIcon(source.kind)),
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
    );
  }
}

/// 시안 랭킹 목록의 번호 블록처럼 테두리 있는 네모 안 아이콘.
class _IconBlock extends StatelessWidget {
  const _IconBlock({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.cyan,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.ink, width: AppBlock.border),
      ),
      child: Icon(icon, size: 24, color: AppColors.ink),
    );
  }
}

class SourceStatusChip extends StatelessWidget {
  const SourceStatusChip({super.key, required this.status});

  final SourceStatus status;

  @override
  Widget build(BuildContext context) {
    return StatChip(
      label: sourceStatusLabel(status),
      color: sourceStatusColor(status),
      border: false,
    );
  }
}
