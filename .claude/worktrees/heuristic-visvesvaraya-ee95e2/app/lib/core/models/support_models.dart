/// Models for `GET /support/{country}`. Mirrors
/// `backend/app/schemas/support.py`.
///
/// This is the Safety, Reporting & Protection half of the product: not "is
/// this a scam" but "who do I call, in what order, and how fast".
library;

/// Which rung of the escalation ladder a channel sits on. Ordering matters —
/// the wallet provider can still stop a transfer, the police cannot.
typedef ChannelKind = String; // wallet | regulator | police | support

class SupportChannel {
  const SupportChannel({
    required this.kind,
    required this.organisation,
    required this.whatItDoes,
    required this.contact,
    required this.url,
    required this.verified,
  });

  final ChannelKind kind;
  final String organisation;
  final String whatItDoes;
  final String? contact;
  final String? url;

  /// `false` means the organisation is right but the contact string has not
  /// been confirmed against its own published channel. The UI must show that
  /// distinction — presenting an unconfirmed emergency number as fact is its
  /// own safety failure.
  final bool verified;

  factory SupportChannel.fromJson(Map<String, dynamic> json) {
    return SupportChannel(
      kind: json['kind'] as String,
      organisation: json['organisation'] as String,
      whatItDoes: json['what_it_does'] as String,
      contact: json['contact'] as String?,
      url: json['url'] as String?,
      verified: json['verified'] as bool? ?? false,
    );
  }
}

class SupportPathway {
  const SupportPathway({
    required this.country,
    required this.countryName,
    required this.category,
    required this.immediateSteps,
    required this.categoryFirstAction,
    required this.channels,
    required this.dataNote,
  });

  final String country;
  final String countryName;
  final String? category;

  /// What to do in the next few minutes, most urgent first.
  final List<String> immediateSteps;
  final String? categoryFirstAction;
  final List<SupportChannel> channels;
  final String dataNote;

  List<SupportChannel> channelsOfKind(ChannelKind kind) {
    return channels.where((SupportChannel c) => c.kind == kind).toList();
  }

  factory SupportPathway.fromJson(Map<String, dynamic> json) {
    return SupportPathway(
      country: json['country'] as String,
      countryName: json['country_name'] as String,
      category: json['category'] as String?,
      immediateSteps: List<String>.from(json['immediate_steps'] as List<dynamic>),
      categoryFirstAction: json['category_first_action'] as String?,
      channels: (json['channels'] as List<dynamic>)
          .map((dynamic e) => SupportChannel.fromJson(e as Map<String, dynamic>))
          .toList(),
      dataNote: json['data_note'] as String,
    );
  }
}
