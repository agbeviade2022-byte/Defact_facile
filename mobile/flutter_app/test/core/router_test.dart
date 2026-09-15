import 'package:defact_facile/core/router/app_router.dart';
import 'package:defact_facile/core/router/app_routes.dart';
import 'package:defact_facile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _app(String location) {
  GoogleFonts.config.allowRuntimeFetching = false;
  return ProviderScope(
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: buildRouter(initialLocation: location),
    ),
  );
}

void main() {
  testWidgets('login screen renders with brand tagline', (tester) async {
    await tester.pumpWidget(_app(AppRoutes.login));
    await tester.pumpAndSettle();
    expect(find.text('Devis. Factures. Gestion. Facile.'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
  });

  testWidgets('personal shell shows 5 tabs and switches branch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(AppRoutes.personalHome));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Devis'), findsOneWidget);

    await tester.tap(find.text('Devis'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mission 05'), findsOneWidget);
  });

  testWidgets('business shell uses navigation rail on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(AppRoutes.businessHome));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
  });

  testWidgets('unknown route shows error state', (tester) async {
    await tester.pumpWidget(_app('/nope'));
    await tester.pumpAndSettle();
    expect(find.text('Page introuvable'), findsWidgets);
  });
}
