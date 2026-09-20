import 'package:chengetai/core/models/sentinel_models.dart';
import 'package:chengetai/features/sentinel/widgets/flagged_transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Currency-correctness tests for the Sentinel flagged-transaction tile.
///
/// The tile used to format every amount with a hardcoded "$", which was
/// harmless only while Sentinel was a Zimbabwe/USD-only demo. Across seven
/// markets that silently restates a Nigerian naira figure as dollars — a
/// number an analyst may act on — so the symbol the backend reports for the
/// run is pinned here rather than left to be spotted by eye.
void main() {
  FlaggedTransaction transaction({
    String currencyCode = 'NGN',
    String currencySymbol = '₦',
    double amount = 495000,
  }) {
    return FlaggedTransaction(
      transactionId: 'TX00042',
      timestamp: DateTime.utc(2026, 7, 1, 3, 2),
      agentId: 'AGT-2201',
      customerMsisdn: '08031234567',
      type: 'cash_out',
      amount: amount,
      anomalyScore: 0.71,
      reasons: const <String>['Structuring pattern detected.'],
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
    );
  }

  group('FlaggedTransaction.formattedAmount', () {
    test('uses the currency symbol the backend reported for the run', () {
      expect(transaction().formattedAmount, '₦495,000.00');
    });

    test('formats each market in its own currency', () {
      expect(
        transaction(currencyCode: 'KES', currencySymbol: 'KSh').formattedAmount,
        'KSh495,000.00',
      );
      expect(
        transaction(currencyCode: 'USD', currencySymbol: r'$').formattedAmount,
        r'$495,000.00',
      );
    });

    test('renders a bare amount when the run carried no currency', () {
      // Better an unlabelled number than one labelled with a currency the
      // backend never reported.
      final String formatted =
          transaction(currencyCode: '', currencySymbol: '').formattedAmount;
      expect(formatted, '495,000.00');
      expect(formatted, isNot(contains(r'$')));
    });

    test('parses the currency fields off the wire, defaulting to unlabelled', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'transaction_id': 'TX00042',
        'timestamp': '2026-07-01T03:02:00Z',
        'agent_id': 'AGT-2201',
        'customer_msisdn': '08031234567',
        'type': 'cash_out',
        'amount': 495000,
        'anomaly_score': 0.71,
        'reasons': <dynamic>['Structuring pattern detected.'],
        'currency_code': 'NGN',
        'currency_symbol': '₦',
      };

      expect(FlaggedTransaction.fromJson(json).formattedAmount, '₦495,000.00');

      // An older backend that predates these fields must not crash the app.
      final Map<String, dynamic> legacy = Map<String, dynamic>.from(json)
        ..remove('currency_code')
        ..remove('currency_symbol');
      expect(FlaggedTransaction.fromJson(legacy).currencySymbol, '');
      expect(FlaggedTransaction.fromJson(legacy).formattedAmount, '495,000.00');
    });
  });

  group('FlaggedTransactionTile', () {
    testWidgets('shows the naira amount, never a dollar amount', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FlaggedTransactionTile(transaction: transaction())),
        ),
      );

      expect(find.textContaining('₦495,000.00'), findsOneWidget);
      expect(find.textContaining(r'$495,000.00'), findsNothing);
    });

    testWidgets('detail sheet spells out the ISO code alongside the symbol',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FlaggedTransactionTile(transaction: transaction())),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.text('₦495,000.00'), findsOneWidget);
      expect(find.text('NGN'), findsOneWidget);
    });
  });
}
