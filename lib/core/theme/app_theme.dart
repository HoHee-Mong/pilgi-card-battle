import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// 앱 전체 테마. 값은 모두 [tokens.dart]에서 가져온다.
/// 블록 UI(굵은 테두리 + 딱딱한 그림자)는 공용 위젯 ChunkyButton·ChunkyCard가 그린다.
/// 여기서는 Material 기본 위젯도 같은 분위기로 보이게 맞춘다.
abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.grape,
      onPrimary: AppColors.paper,
      secondary: AppColors.pink,
      onSecondary: AppColors.ink,
      tertiary: AppColors.lime,
      onTertiary: AppColors.ink,
      error: AppColors.pink,
      onError: AppColors.ink,
      errorContainer: AppColors.wrong,
      onErrorContainer: AppColors.ink,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSub,
      outline: AppColors.ink,
      outlineVariant: AppColors.line,
    );

    const textTheme = TextTheme(
      displaySmall: AppTextStyles.titleL,
      headlineMedium: AppTextStyles.titleM,
      titleLarge: AppTextStyles.heading,
      titleMedium: AppTextStyles.heading,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.bodyS,
      bodySmall: AppTextStyles.caption,
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.label,
    );

    const inkSide = BorderSide(color: AppColors.ink, width: AppBlock.border);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
      side: inkSide,
    );
    const buttonMinSize = Size(AppSpacing.minTouch, AppSpacing.minTouch);
    OutlineInputBorder inputBorder(double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
      borderSide: BorderSide(color: AppColors.ink, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: AppFonts.family,
      fontFamilyFallback: AppFonts.fallback,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading,
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: inkSide,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pink,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.inkSub,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: AppTextStyles.button,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.grape,
          minimumSize: buttonMinSize,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.paper,
          side: inkSide,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: AppTextStyles.button,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.pink,
        foregroundColor: AppColors.ink,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: AppTextStyles.button,
        shape: buttonShape,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paper,
        selectedColor: AppColors.lime,
        labelStyle: AppTextStyles.label.copyWith(color: AppColors.ink),
        side: const BorderSide(color: AppColors.ink, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.inkSub),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: inputBorder(2),
        enabledBorder: inputBorder(2),
        focusedBorder: inputBorder(AppBlock.border),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cream,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.ink,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTextStyles.bodyS.copyWith(color: AppColors.paper),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.paper,
        elevation: 0,
        indicatorColor: AppColors.lime,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: const BorderSide(color: AppColors.ink, width: 2),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.label.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.inkSub,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.inkSub,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
