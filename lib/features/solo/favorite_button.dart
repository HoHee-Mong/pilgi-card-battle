import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme/tokens.dart';
import 'solo_providers.dart';

/// 카드 즐겨찾기 별. 상태는 `users/{uid}/cardMeta/{cardId}.favorite` (나만 보임).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(cardMetaProvider).value?[cardId]?.favorite ?? false;
    return IconButton(
      tooltip: on ? '즐겨찾기 빼기' : '즐겨찾기',
      icon: Icon(
        on ? Icons.star_rounded : Icons.star_border_rounded,
        color: on ? AppColors.sun : AppColors.inkSub,
        size: 28,
      ),
      onPressed: () {
        final uid = ref.read(uidProvider);
        if (uid == null) return;
        ref.read(attemptRepositoryProvider).setFavorite(uid, cardId, !on);
      },
    );
  }
}

/// 내 즐겨찾기 카드 ID 모음.
final favoriteIdsProvider = Provider<Set<String>>((ref) {
  final meta = ref.watch(cardMetaProvider).value ?? const {};
  return {
    for (final e in meta.entries)
      if (e.value.favorite) e.key,
  };
});
