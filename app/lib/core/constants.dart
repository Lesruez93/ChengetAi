/// App-wide constants: API configuration, the country registry, and the scam
/// category list used to populate form pickers.
///
/// The country and category data mirror
/// `backend/app/services/countries.py` and `backend/app/services/taxonomy.py`.
/// They are duplicated here (rather than only fetched from
/// `GET /reference/countries`) so the report sheet and the country picker
/// render instantly and work offline — which matters most in exactly the
/// low-connectivity conditions where someone is trying to check a message.
/// `CountryRegistry.refreshFrom` lets the app overlay live reference data
/// when it does reach the API, so a country added on the backend appears
/// without an app release.
library;

class AppConfig {
  const AppConfig._();

  /// Backend base URL.
  ///
  /// Defaults to `10.0.2.2`, the special alias the Android emulator uses to
  /// reach the host machine's `localhost` — so `uvicorn app.main:app --reload`
  /// running on your dev machine is reachable out of the box when you run
  /// this app in the emulator. It will NOT work on a physical device or in
  /// release builds; override it at build/run time:
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
  ///   flutter build apk --dart-define=API_BASE_URL=https://api.chengetai.example
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const Duration apiTimeout = Duration(seconds: 20);

  /// Country selected on first launch, before the user picks their own.
  /// Mirrors the backend's `DEFAULT_COUNTRY` setting.
  static const String defaultCountryCode = 'ZW';
}

/// One market's locale data. Mirrors `Country` in
/// `backend/app/services/countries.py`.
class CountryProfile {
  const CountryProfile({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.regionLabel,
    required this.regions,
    required this.providers,
    required this.exampleMsisdn,
  });

  /// ISO 3166-1 alpha-2, e.g. `KE`.
  final String code;
  final String name;

  /// Country calling code without the `+`, e.g. `254`.
  final String dialCode;

  /// What this country calls its first-level unit — Province, Region, Zone.
  /// Used as the picker's label, so a Kenyan user is never asked for a
  /// "province" and a Nigerian user is never asked for a "county".
  final String regionLabel;

  final List<String> regions;

  /// Mobile-money wallets in everyday use, shown in help text so the app
  /// reads as local rather than imported.
  final List<String> providers;

  /// A syntactically valid local-format number, used as placeholder text.
  final String exampleMsisdn;

  factory CountryProfile.fromJson(Map<String, dynamic> json) {
    return CountryProfile(
      code: json['code'] as String,
      name: json['name'] as String,
      dialCode: json['dial_code'] as String,
      regionLabel: json['region_label'] as String,
      regions: List<String>.from(json['regions'] as List<dynamic>),
      providers: List<String>.from(json['providers'] as List<dynamic>),
      exampleMsisdn: json['example_msisdn'] as String,
    );
  }
}

/// The bundled country list, overlayable with live data from the API.
class CountryRegistry {
  CountryRegistry._();

  static List<CountryProfile> _countries = _bundled;

  static List<CountryProfile> get all => List<CountryProfile>.unmodifiable(_countries);

  /// Look up by ISO code, falling back to the default country so a stale or
  /// unknown stored preference can never leave the UI without a market.
  static CountryProfile byCode(String code) {
    final String wanted = code.toUpperCase();
    for (final CountryProfile c in _countries) {
      if (c.code == wanted) {
        return c;
      }
    }
    return _countries.firstWhere(
      (CountryProfile c) => c.code == AppConfig.defaultCountryCode,
      orElse: () => _countries.first,
    );
  }

  /// Replace the bundled list with live reference data from
  /// `GET /reference/countries`. Ignores an empty response rather than
  /// blanking the picker if the call half-fails.
  static void refreshFrom(List<CountryProfile> fetched) {
    if (fetched.isNotEmpty) {
      _countries = fetched;
    }
  }

  static const List<CountryProfile> _bundled = <CountryProfile>[
    CountryProfile(
      code: 'ZW',
      name: 'Zimbabwe',
      dialCode: '263',
      regionLabel: 'Province',
      regions: <String>[
        'Harare', 'Bulawayo', 'Manicaland', 'Mashonaland Central',
        'Mashonaland East', 'Mashonaland West', 'Masvingo',
        'Matabeleland North', 'Matabeleland South', 'Midlands',
      ],
      providers: <String>['EcoCash', 'OneMoney', 'InnBucks'],
      exampleMsisdn: '0711234567',
    ),
    CountryProfile(
      code: 'KE',
      name: 'Kenya',
      dialCode: '254',
      regionLabel: 'Region',
      regions: <String>[
        'Nairobi', 'Central', 'Coast', 'Eastern',
        'North Eastern', 'Nyanza', 'Rift Valley', 'Western',
      ],
      providers: <String>['M-PESA', 'Airtel Money', 'T-Kash'],
      exampleMsisdn: '0712345678',
    ),
    CountryProfile(
      code: 'NG',
      name: 'Nigeria',
      dialCode: '234',
      regionLabel: 'Zone',
      regions: <String>[
        'Lagos', 'FCT Abuja', 'South West', 'South East',
        'South South', 'North Central', 'North East', 'North West',
      ],
      providers: <String>['OPay', 'PalmPay', 'Moniepoint', 'Paga', 'MTN MoMo', 'Kuda'],
      exampleMsisdn: '07012345678',
    ),
    CountryProfile(
      code: 'UG',
      name: 'Uganda',
      dialCode: '256',
      regionLabel: 'Region',
      regions: <String>['Central', 'Eastern', 'Northern', 'Western'],
      providers: <String>['MTN MoMo', 'Airtel Money'],
      exampleMsisdn: '0701234567',
    ),
    CountryProfile(
      code: 'ZA',
      name: 'South Africa',
      dialCode: '27',
      regionLabel: 'Province',
      regions: <String>[
        'Gauteng', 'Western Cape', 'KwaZulu-Natal', 'Eastern Cape',
        'Free State', 'Limpopo', 'Mpumalanga', 'North West', 'Northern Cape',
      ],
      providers: <String>[
        'Capitec Pay', 'FNB eWallet', 'Standard Bank Instant Money',
        'ShopriteMoney', 'MTN MoMo',
      ],
      exampleMsisdn: '0612345678',
    ),
    CountryProfile(
      code: 'GH',
      name: 'Ghana',
      dialCode: '233',
      regionLabel: 'Region',
      regions: <String>[
        'Greater Accra', 'Ashanti', 'Central', 'Eastern', 'Western',
        'Volta', 'Northern', 'Bono', 'Upper East', 'Upper West',
      ],
      providers: <String>['MTN MoMo', 'Telecel Cash', 'AirtelTigo Money'],
      exampleMsisdn: '0212345678',
    ),
    CountryProfile(
      code: 'TZ',
      name: 'Tanzania',
      dialCode: '255',
      regionLabel: 'Zone',
      regions: <String>[
        'Dar es Salaam', 'Coastal', 'Northern', 'Lake',
        'Central', 'Southern Highlands', 'Western', 'Zanzibar',
      ],
      providers: <String>['M-Pesa', 'Mixx by Yas', 'Airtel Money', 'HaloPesa'],
      exampleMsisdn: '0612345678',
    ),
  ];
}

/// Scam report categories, mirrored from
/// `backend/app/services/taxonomy.py::SCAM_CATEGORIES`.
///
/// Keys describe the *mechanism*, not the wallet brand, so one list works in
/// every market — "reverse this wrong deposit" is the same attack whether the
/// message says EcoCash, M-PESA or OPay.
const List<String> kScamCategories = <String>[
  'mobile_money_reversal',
  'fake_job',
  'fake_investment',
  'fake_loan_aid',
  'sim_swap',
  'otp_phishing',
  'impersonation',
  'faith_seed',
  'other',
];

/// Human-readable labels for the categories above, mirroring the backend's
/// `ScamCategory.label`. Falls back to a title-cased key so an unrecognised
/// category from a newer backend still renders legibly.
const Map<String, String> kScamCategoryLabels = <String, String>{
  'mobile_money_reversal': 'Wrong deposit / reversal',
  'fake_job': 'Fake job or recruitment',
  'fake_investment': 'Fake investment, forex or crypto',
  'fake_loan_aid': 'Fake loan, grant or relief aid',
  'sim_swap': 'SIM swap or line suspension',
  'otp_phishing': 'OTP, PIN or ID phishing',
  'impersonation': 'Bank, telco or agent impersonation',
  'faith_seed': "Faith-based 'seed' request",
  'other': 'Other',
};

/// Turns a category key into a human-readable label, e.g.
/// `mobile_money_reversal` -> `Wrong deposit / reversal`.
String humanizeCategory(String category) {
  final String? label = kScamCategoryLabels[category];
  if (label != null) {
    return label;
  }
  return category
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
