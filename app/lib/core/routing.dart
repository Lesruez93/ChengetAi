import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/home/home_shell.dart';

/// App-wide route table.
///
/// Auth is a stub (see `features/auth/`), so `/` goes straight to the login
/// screen, which offers "Continue as guest" alongside the (non-functional)
/// email/password form — the demo never blocks on real authentication.
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: <RouteBase>[
    GoRoute(path: '/login', builder: (BuildContext context, GoRouterState state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (BuildContext context, GoRouterState state) => const SignupScreen()),
    GoRoute(path: '/home', builder: (BuildContext context, GoRouterState state) => const HomeShell()),
  ],
);
