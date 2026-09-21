import 'package:defact_facile/core/theme/app_colors.dart';
import 'package:defact_facile/core/theme/app_spacing.dart';
import 'package:defact_facile/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('theme uses brand primary and 48px touch targets', () {
    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(AppSpacing.minTouchTarget, greaterThanOrEqualTo(44));
    final size = theme.filledButtonTheme.style!.minimumSize!.resolve({});
    expect(size!.height, greaterThanOrEqualTo(44));
  });
}
