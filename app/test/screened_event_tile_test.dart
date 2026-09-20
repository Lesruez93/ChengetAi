import 'package:chengetai/core/models/screened_event.dart';
import 'package:chengetai/features/call_guard/widgets/screened_event_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout regression tests for the Call Guard history tile.
///
/// The tile packs an icon, a sender, a channel/date line and a verdict label
/// into one row, and every one of those is variable-width: senders range from
/// a short contact name to a full international number, and verdicts from
/// "Warned" to "Flagged — warning blocked". That combination overflowed on a
/// normal-width phone once already, so the widths are pinned here rather than
/// left to be caught by eye on a debug build.
///
/// A RenderFlex overflow is reported through `FlutterError.onError`, which the
/// test binding captures — `tester.takeException()` returns it, so these tests
/// fail on overflow rather than merely rendering the yellow-and-black stripes.
void main() {
  /// Widths worth pinning: 320 is the narrowest phone still in real use,
  /// 360 and 393 are the common Android and mid-size defaults.
  const List<double> widths = <double>[320, 360, 393];

  /// Long enough to exercise ellipsis: a full international number in the
  /// spaced format the tile receives, and a WhatsApp contact name.
  const List<String> senders = <String>[
    '+263 71 042 3555',
    '+234 803 123 4567',
    'Tendai from the agent shop',
  ];

  Widget wrap(ScreenedEvent event, double width) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ScreenedEventTile(event: event),
          ),
        ),
      ),
    );
  }

  ScreenedEvent event({
    required ScreeningOutcome outcome,
    required ThreatChannel channel,
    required String sender,
    bool wasSimulated = false,
    bool withSignals = true,
  }) {
    return ScreenedEvent(
      channel: channel,
      sender: sender,
      // A month abbreviation of maximum width, to catch the widest date string.
      screenedAt: DateTime(2026, 9, 19, 14, 14),
      outcome: outcome,
      wasWarned: outcome == ScreeningOutcome.warned,
      wasSimulated: wasSimulated,
      riskLevel: withSignals ? 'high' : null,
      reportCount: withSignals ? 4 : null,
      topCategory: withSignals ? 'mobile_money_reversal' : null,
      messageVerdict: withSignals ? 'scam' : null,
    );
  }

  testWidgets('renders every outcome and channel without overflow', (WidgetTester tester) async {
    for (final double width in widths) {
      for (final ScreeningOutcome outcome in ScreeningOutcome.values) {
        for (final ThreatChannel channel in ThreatChannel.values) {
          for (final String sender in senders) {
            await tester.pumpWidget(
              wrap(event(outcome: outcome, channel: channel, sender: sender), width),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'overflowed at ${width}px — $outcome / $channel / "$sender"',
            );
          }
        }
      }
    }
  });

  testWidgets('the TEST badge does not push the row into overflow', (WidgetTester tester) async {
    for (final double width in widths) {
      await tester.pumpWidget(
        wrap(
          event(
            outcome: ScreeningOutcome.flaggedNotificationBlocked,
            channel: ThreatChannel.whatsappCall,
            sender: '+263 71 042 3555',
            wasSimulated: true,
          ),
          width,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'overflowed at ${width}px with TEST badge');
    }
  });

  testWidgets('a tile with no reputation signals still lays out', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        event(
          outcome: ScreeningOutcome.noNumberAvailable,
          channel: ThreatChannel.whatsappCall,
          sender: 'Tendai from the agent shop',
          withSignals: false,
        ),
        320,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the verdict label stays visible when the sender is long',
      (WidgetTester tester) async {
    // The verdict is the point of the row: a long sender must ellipsize
    // rather than crowd the label out of the tile.
    await tester.pumpWidget(
      wrap(
        event(
          outcome: ScreeningOutcome.warned,
          channel: ThreatChannel.whatsappCall,
          sender: '+263 71 042 3555',
        ),
        320,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Warned'), findsOneWidget);

    final double labelWidth = tester.getSize(find.text('Warned')).width;
    expect(labelWidth, greaterThan(0));
  });

  testWidgets('no verdict label stacks tall enough to inflate the card',
      (WidgetTester tester) async {
    // Capping the label's width without capping its lines just trades a
    // horizontal overflow for a vertical one: the longest verdict wrapped
    // four lines deep and stretched the card past the content it labels.
    // Every outcome's header row must stay within two lines of the label.
    const double maxHeaderHeight = 2 * 12.5 * 1.4 + 4;
    for (final ScreeningOutcome outcome in ScreeningOutcome.values) {
      await tester.pumpWidget(
        wrap(
          event(outcome: outcome, channel: ThreatChannel.sms, sender: '+263 71 042 3555'),
          393,
        ),
      );
      expect(tester.takeException(), isNull);
      final double labelHeight = tester.getSize(find.text(outcome.label)).height;
      expect(
        labelHeight,
        lessThanOrEqualTo(maxHeaderHeight),
        reason: '"${outcome.label}" wrapped beyond two lines (${labelHeight}px)',
      );
    }
  });

  testWidgets('a short verdict does not reserve half the row', (WidgetTester tester) async {
    // Regression guard for the layout, not just the overflow. Pairing a
    // flex-1 Expanded with a flex-1 sibling splits the row evenly no matter
    // how little the sibling needs, which truncated a number that had room
    // to render in full. "Warned" is ~50px wide, so the sender must get
    // substantially more than half of a 393px tile.
    await tester.pumpWidget(
      wrap(
        event(
          outcome: ScreeningOutcome.warned,
          channel: ThreatChannel.whatsappCall,
          sender: '+263 71 042 3555',
        ),
        393,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('+263 71 042 3555')).width, greaterThan(220));
  });
}
