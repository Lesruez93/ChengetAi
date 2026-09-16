import 'package:chengetai/core/constants.dart';
import 'package:chengetai/core/models/classify_models.dart';
import 'package:chengetai/core/models/feed_models.dart';
import 'package:chengetai/core/models/reputation_models.dart';
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
  });
}
