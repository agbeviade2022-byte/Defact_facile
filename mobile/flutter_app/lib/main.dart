import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'go_router.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const DefactFacileApp());
}

class DefactFacileApp extends StatelessWidget {
  const DefactFacileApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AiService()),
        ChangeNotifierProvider(create: (_) => WalletService()),
        ChangeNotifierProvider(create: (_) => PaymentService()),
      ],
      child: MaterialApp.router(
        title: 'DEFACT FACILE',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: goRouter,
      ),
    );
  }
}