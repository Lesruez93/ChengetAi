import 'package:flutter/material.dart';

import 'core/country_preference.dart';
import 'core/routing.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loaded before the first frame so no screen ever renders against the
  // wrong market and then flips — a lookup fired against the default country
  // would resolve a local number to the wrong person entirely.
  await CountryPreference.load();
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
