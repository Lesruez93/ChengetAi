import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../check_message/check_message_screen.dart';
import '../feed/feed_screen.dart';
import '../lookup/lookup_screen.dart';
import '../sentinel/sentinel_screen.dart';
import '../support/support_screen.dart';

/// Bottom-nav shell tying the consumer and B2B features together.
///
/// "Help" is a top-level tab rather than only a destination after a verdict:
/// someone who has already sent money, or who was phoned rather than texted,
/// needs the escalation ladder without first pasting a message they may not
/// have.
///
/// A single [ApiClient] instance is created here and threaded down to every
/// tab, so all screens share one `http.Client` (connection reuse) instead
/// of each constructing its own.
///
/// Tabs are kept alive via [IndexedStack] rather than rebuilt on every
/// switch, so a half-typed message or an in-progress sentinel upload
/// survives navigating away and back.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final ApiClient _apiClient = ApiClient();
  int _index = 0;

  late final List<Widget> _tabs = <Widget>[
    CheckMessageScreen(apiClient: _apiClient),
    LookupScreen(apiClient: _apiClient),
    SupportScreen(apiClient: _apiClient),
    FeedScreen(apiClient: _apiClient),
    SentinelScreen(apiClient: _apiClient),
  ];

  static const List<NavigationDestination> _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Check'),
    NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Lookup'),
    NavigationDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: 'Help'),
    NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: 'Alerts'),
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Sentinel'),
  ];

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _tabs),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
