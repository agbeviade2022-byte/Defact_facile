import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/ai/presentation/pages/ai_chat_page.dart';

final goRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // Authentication routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    // Dashboard routes
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),

    // AI routes
    GoRoute(
      path: '/ai-chat',
      builder: (context, state) => const AiChatPage(),
    ),

    // TODO: Add more routes as we implement features
  ],
);