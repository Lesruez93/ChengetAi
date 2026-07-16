import 'package:flutter_test/flutter_test.dart';

import 'package:chengetai/main.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ChengetAiApp());
    await tester.pump();
  });
}
