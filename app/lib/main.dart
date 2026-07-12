import 'package:flutter/material.dart';

import 'core/routing.dart';
import 'core/theme.dart';

void main() {
  runApp(const ChengetAiApp());
}

class ChengetAiApp extends StatelessWidget {
  const ChengetAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ChengetAI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
