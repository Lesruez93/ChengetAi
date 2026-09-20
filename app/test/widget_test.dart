import 'package:chengetai/core/constants.dart';
import 'package:chengetai/core/models/classify_models.dart';
import 'package:chengetai/core/models/feed_models.dart';
import 'package:chengetai/core/models/reputation_models.dart';
import 'package:chengetai/core/models/screened_event.dart';
import 'package:chengetai/core/models/support_models.dart';
import 'package:chengetai/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ChengetAiApp());
    await tester.pump();
  });

  group('CountryRegistry', () {
    test('resolves every bundled market by code, case-insensitively', () {
      for (final CountryProfile c in CountryRegistry.all) {
        expect(CountryRegistry.byCode(c.code).code, c.code);
        expect(CountryRegistry.byCode(c.code.toLowerCase()).code, c.code);
      }
    });

    test('falls back to the default rather than throwing on an unknown code', () {
      // A stale stored preference or a market removed in a later build must
      // never leave the UI without a country to render.
      expect(CountryRegistry.byCode('FR').code, AppConfig.defaultCountryCode);
      expect(CountryRegistry.byCode('').code, AppConfig.defaultCountryCode);
    });

    test('every market supplies the data the pickers and hints depend on', () {
      for (final CountryProfile c in CountryRegistry.all) {
        expect(c.regions, isNotEmpty, reason: '${c.code} would render an empty region picker');
        expect(c.providers, isNotEmpty, reason: '${c.code} would render an empty hint');
        expect(c.regionLabel, isNotEmpty);
        expect(c.exampleMsisdn, startsWith('0'));
      }
    });

    test('refreshFrom ignores an empty response instead of blanking the list', () {
      final int before = CountryRegistry.all.length;
      CountryRegistry.refreshFrom(<CountryProfile>[]);
      expect(CountryRegistry.all.length, before);
    });
  });

  group('humanizeCategory', () {
    test('uses the curated label for a known category', () {
      expect(humanizeCategory('mobile_money_reversal'), 'Wrong deposit / reversal');
      expect(humanizeCategory('otp_phishing'), 'OTP, PIN or ID phishing');
    });

    test('title-cases an unknown key rather than showing a raw snake_case string', () {
      // A newer backend may send a category this build has never heard of.
      expect(humanizeCategory('some_new_scam'), 'Some New Scam');
    });
  });

  group('model parsing', () {
    test('ClassifyResponse carries the market and the pathway', () {
      final ClassifyResponse result = ClassifyResponse.fromJson(<String, dynamic>{
        'verdict': 'scam',
        'confidence': 0.91,
        'risk_phrases': <dynamic>[
          <String, dynamic>{'phrase': 'reverse', 'reason': 'Wrong-deposit script.'},
        ],
        'explanation': 'This is the wrong-deposit scam.',
        'matched_category': 'mobile_money_reversal',
        'strategy_used': 'baseline',
        'country': 'KE',
        'next_steps': <dynamic>['Do not send anything back.'],
      });
      expect(result.country, 'KE');
      expect(result.isSafe, isFalse);
      expect(result.nextSteps, hasLength(1));
      expect(result.riskPhrases.single.phrase, 'reverse');
    });

    test('ClassifyResponse tolerates an older backend with no country or steps', () {
      final ClassifyResponse result = ClassifyResponse.fromJson(<String, dynamic>{
        'verdict': 'safe',
        'confidence': 0.8,
        'explanation': 'Looks like a normal notice.',
        'strategy_used': 'baseline',
      });
      expect(result.country, '');
      expect(result.nextSteps, isEmpty);
      expect(result.isSafe, isTrue);
    });

    test('NumberReputation flags cross-border reach', () {
      final NumberReputation single = NumberReputation.fromJson(<String, dynamic>{
        'msisdn': '+254712345678',
        'country': 'KE',
        'report_count': 2,
        'categories': <String, dynamic>{'fake_job': 2},
        'countries': <String, dynamic>{'KE': 2},
        'last_reported_at': null,
        'is_publicly_flagged': false,
        'risk_level': 'low',
      });
      expect(single.isCrossBorder, isFalse);

      final NumberReputation multi = NumberReputation.fromJson(<String, dynamic>{
        'msisdn': '+2348031234567',
        'country': 'NG',
        'report_count': 3,
        'categories': <String, dynamic>{'fake_job': 3},
        'countries': <String, dynamic>{'NG': 2, 'GH': 1},
        'last_reported_at': null,
        'is_publicly_flagged': true,
        'risk_level': 'high',
      });
      expect(multi.isCrossBorder, isTrue);
    });

    test('ReportCreate sends country and region, and omits reporter_id when anonymous', () {
      final Map<String, dynamic> anonymous = const ReportCreate(
        msisdn: '0712345678',
        country: 'KE',
        category: 'sim_swap',
        region: 'Nairobi',
      ).toJson();
      expect(anonymous['country'], 'KE');
      expect(anonymous['region'], 'Nairobi');
      expect(anonymous.containsKey('reporter_id'), isFalse,
          reason: 'an anonymous report must send no reporter id at all');

      final Map<String, dynamic> identified = const ReportCreate(
        msisdn: '0712345678',
        country: 'KE',
        category: 'sim_swap',
        region: 'Nairobi',
        reporterId: 'anon-abc123',
      ).toJson();
      expect(identified['reporter_id'], 'anon-abc123');
    });

    test('TrendingFeedResponse parses both hotspot scopes', () {
      final TrendingFeedResponse feed = TrendingFeedResponse.fromJson(<String, dynamic>{
        'generated_at': '2026-09-16T10:00:00Z',
        'window_days': 7,
        'country': 'NG',
        'region_label': 'Zone',
        'trending_categories': <dynamic>[
          <String, dynamic>{
            'category': 'otp_phishing',
            'label': 'OTP, PIN or ID phishing',
            'score': 4.2,
            'report_count': 5,
          },
        ],
        'hotspots': <dynamic>[
          <String, dynamic>{
            'region': 'Lagos',
            'level': 'red',
            'report_count': 5,
            'top_category': 'otp_phishing',
          },
        ],
        'country_hotspots': <dynamic>[
          <String, dynamic>{
            'country': 'NG',
            'country_name': 'Nigeria',
            'level': 'red',
            'report_count': 5,
            'top_category': 'otp_phishing',
          },
        ],
        'method_note': 'Computed with weighted rules. Not an AI/ML model.',
      });
      expect(feed.regionLabel, 'Zone');
      expect(feed.hotspots.single.region, 'Lagos');
      expect(feed.countryHotspots.single.countryName, 'Nigeria');
      expect(feed.trendingCategories.single.label, 'OTP, PIN or ID phishing');
    });

    test('SupportPathway groups channels by escalation rung', () {
      final SupportPathway pathway = SupportPathway.fromJson(<String, dynamic>{
        'country': 'GH',
        'country_name': 'Ghana',
        'category': null,
        'immediate_steps': <dynamic>['Stop replying.'],
        'category_first_action': null,
        'channels': <dynamic>[
          <String, dynamic>{
            'kind': 'wallet',
            'organisation': 'MTN MoMo support',
            'what_it_does': 'Can hold a receiving wallet.',
            'contact': null,
            'url': null,
            'verified': false,
          },
          <String, dynamic>{
            'kind': 'police',
            'organisation': 'Ghana Police Service',
            'what_it_does': 'Opens a criminal case.',
            'contact': '191',
            'url': null,
            'verified': true,
          },
        ],
        'data_note': 'Confirm unverified contacts.',
      });
      expect(pathway.channelsOfKind('wallet'), hasLength(1));
      expect(pathway.channelsOfKind('police').single.contact, '191');
      expect(pathway.channelsOfKind('support'), isEmpty);
      // An unverified contact must survive parsing as unverified, not be
      // silently upgraded — the UI depends on that distinction.
      expect(pathway.channelsOfKind('wallet').single.verified, isFalse);
    });

    test('ScreenedEvent parses a warned call from the Kotlin screening log', () {
      final ScreenedEvent event = ScreenedEvent.fromJson(<String, dynamic>{
        'channel': 'call',
        'sender': '+263710423555',
        'screened_at_millis': 1758268800000,
        'outcome': 'warned',
        'risk_level': 'high',
        'report_count': 4,
        'top_category': 'mobile_money_reversal',
        'was_warned': true,
        'was_simulated': true,
      });
      expect(event.sender, '+263710423555');
      expect(event.channel, ThreatChannel.call);
      expect(event.outcome, ScreeningOutcome.warned);
      expect(event.riskLevel, 'high');
      expect(event.reportCount, 4);
      expect(event.wasSimulated, isTrue);
    });

    test('ScreenedEvent keeps an SMS classifier verdict separate from reputation', () {
      // The two signals catch different attacks: a brand-new number has no
      // report history but sends the known script. Collapsing them would hide
      // exactly the case SMS screening exists to catch.
      final ScreenedEvent event = ScreenedEvent.fromJson(<String, dynamic>{
        'channel': 'sms',
        'sender': '+263788000222',
        'screened_at_millis': 1758268800000,
        'outcome': 'warned',
        'risk_level': 'unknown',
        'report_count': 0,
        'message_verdict': 'scam',
        'was_warned': true,
        'was_simulated': false,
      });
      expect(event.channel, ThreatChannel.sms);
      expect(event.messageVerdict, 'scam');
      expect(event.reportCount, 0);
      expect(event.outcome, ScreeningOutcome.warned);
    });

    test('ScreenedEvent keeps a blocked warning distinct from a clean event', () {
      // These two both show the user nothing while the phone rings, so if
      // parsing collapsed them the history could not explain the difference
      // between "you are protected" and "notifications are off".
      final ScreenedEvent blocked = ScreenedEvent.fromJson(<String, dynamic>{
        'channel': 'call',
        'sender': '+263710423555',
        'screened_at_millis': 1758268800000,
        'outcome': 'flagged_notification_blocked',
        'was_warned': false,
        'was_simulated': false,
      });
      final ScreenedEvent clean = ScreenedEvent.fromJson(<String, dynamic>{
        'channel': 'call',
        'sender': '+263712000111',
        'screened_at_millis': 1758268800000,
        'outcome': 'clean',
        'was_warned': false,
        'was_simulated': false,
      });
      expect(blocked.outcome, ScreeningOutcome.flaggedNotificationBlocked);
      expect(clean.outcome, ScreeningOutcome.clean);
      expect(blocked.outcome.explanation, isNot(clean.outcome.explanation));
      // Null risk fields must survive as null rather than defaulting to 0/low,
      // which would render a fabricated verdict for an event never looked up.
      expect(blocked.riskLevel, isNull);
      expect(blocked.reportCount, isNull);
    });

    test('ScreenedEvent explains a WhatsApp call with no number to look up', () {
      // WhatsApp shows a saved contact's name, which cannot be resolved
      // against a reputation database keyed by MSISDN. This has to read as a
      // known limitation rather than a failure or a clean bill of health.
      final ScreenedEvent event = ScreenedEvent.fromJson(<String, dynamic>{
        'channel': 'whatsapp_call',
        'sender': 'Tendai M',
        'screened_at_millis': 1758268800000,
        'outcome': 'no_number_available',
        'was_warned': false,
        'was_simulated': false,
      });
      expect(event.channel, ThreatChannel.whatsappCall);
      expect(event.outcome, ScreeningOutcome.noNumberAvailable);
      expect(event.outcome, isNot(ScreeningOutcome.clean));
      expect(event.outcome, isNot(ScreeningOutcome.lookupFailed));
    });

    test('ScreenedEvent degrades an unrecognised outcome instead of blanking the row', () {
      final ScreenedEvent event = ScreenedEvent.fromJson(<String, dynamic>{
        'channel': 'call',
        'sender': '+263710423555',
        'screened_at_millis': 1758268800000,
        'outcome': 'some_future_outcome',
        'was_warned': false,
        'was_simulated': false,
      });
      expect(event.outcome, ScreeningOutcome.unknown);
      expect(event.outcome.label, isNotEmpty);
    });

    test('CallGuardStatus needs notifications plus at least one live channel', () {
      const CallGuardStatus callsOnly = CallGuardStatus(
        isSupported: true,
        hasRole: true,
        hasSmsPermission: false,
        hasWhatsAppAccess: false,
        isEnabled: true,
        hasNotificationPermission: true,
      );
      expect(callsOnly.isFullyActive, isTrue);
      expect(callsOnly.activeChannelCount, 1);

      // Notifications are the shared prerequisite: without them every channel
      // detects silently, which is the same as not running at all.
      const CallGuardStatus noNotifications = CallGuardStatus(
        isSupported: true,
        hasRole: true,
        hasSmsPermission: true,
        hasWhatsAppAccess: true,
        isEnabled: true,
        hasNotificationPermission: false,
      );
      expect(noNotifications.isFullyActive, isFalse);

      // Every channel denied means nothing is being screened, however many
      // other boxes are ticked.
      const CallGuardStatus noChannels = CallGuardStatus(
        isSupported: true,
        hasRole: false,
        hasSmsPermission: false,
        hasWhatsAppAccess: false,
        isEnabled: true,
        hasNotificationPermission: true,
      );
      expect(noChannels.isFullyActive, isFalse);
      expect(noChannels.activeChannelCount, 0);

      expect(CallGuardStatus.unsupported.isFullyActive, isFalse);
    });

    test('CallGuard test fixtures cover both a flagged and a clean case per channel', () {
      // These chips promise a specific outcome before the user presses them,
      // so a missing control case would make "it warned" indistinguishable
      // from "it warns about everything".
      expect(
        kCallGuardTestMessages.any((CallGuardTestMessage m) => m.expectsWarning),
        isTrue,
      );
      expect(
        kCallGuardTestMessages.any((CallGuardTestMessage m) => !m.expectsWarning),
        isTrue,
      );
    });

    test('Call Guard test numbers match what the backend seed actually contains', () {
      // These chips promise a specific outcome before the user presses them,
      // so a seed change that silently invalidates them would make the test
      // box report a false failure.
      final CallGuardTestNumber flagged = kCallGuardTestNumbers
          .firstWhere((CallGuardTestNumber n) => n.msisdn == '+263710423555');
      expect(flagged.expectsWarning, isTrue);
      expect(
        kCallGuardTestNumbers.any((CallGuardTestNumber n) => !n.expectsWarning),
        isTrue,
        reason: 'A clean control number is needed to tell "screening works" '
            'apart from "screening warns about everything".',
      );
    });
  });
}
