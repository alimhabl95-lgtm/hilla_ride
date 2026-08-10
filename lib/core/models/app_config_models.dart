class AppRemoteConfig {
  const AppRemoteConfig({
    this.maintenanceMode = false,
    this.maintenanceMessageEn = '',
    this.maintenanceMessageAr = '',
    this.minAndroidBuild = 0,
    this.minIosBuild = 0,
    this.forceUpdateMessageEn = '',
    this.forceUpdateMessageAr = '',
    this.androidStoreUrl = '',
    this.iosStoreUrl = '',
    this.aboutEn = '',
    this.aboutAr = '',
    this.contactEn = '',
    this.contactAr = '',
    this.privacyEn = '',
    this.privacyAr = '',
    this.termsEn = '',
    this.termsAr = '',
    this.referralEnabled = false,
    this.referralRewardReferrerIqd = 0,
    this.referralRewardNewUserIqd = 0,
    this.complaintFlagThreshold = 3,
  });

  final bool maintenanceMode;
  final String maintenanceMessageEn;
  final String maintenanceMessageAr;
  final int minAndroidBuild;
  final int minIosBuild;
  final String forceUpdateMessageEn;
  final String forceUpdateMessageAr;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final String aboutEn;
  final String aboutAr;
  final String contactEn;
  final String contactAr;
  final String privacyEn;
  final String privacyAr;
  final String termsEn;
  final String termsAr;
  final bool referralEnabled;
  final int referralRewardReferrerIqd;
  final int referralRewardNewUserIqd;
  final int complaintFlagThreshold;

  static const defaults = AppRemoteConfig();

  String maintenanceMessageFor(String languageCode) =>
      languageCode.startsWith('ar') ? maintenanceMessageAr : maintenanceMessageEn;

  String forceUpdateMessageFor(String languageCode) =>
      languageCode.startsWith('ar') ? forceUpdateMessageAr : forceUpdateMessageEn;

  String aboutFor(String languageCode) =>
      languageCode.startsWith('ar') ? aboutAr : aboutEn;

  String contactFor(String languageCode) =>
      languageCode.startsWith('ar') ? contactAr : contactEn;

  String privacyFor(String languageCode) =>
      languageCode.startsWith('ar') ? privacyAr : privacyEn;

  String termsFor(String languageCode) =>
      languageCode.startsWith('ar') ? termsAr : termsEn;

  factory AppRemoteConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return defaults;

    int readInt(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? fallback;
    }

    bool readBool(dynamic value, bool fallback) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = '$value'.toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
      return fallback;
    }

    String readString(dynamic value) => (value ?? '').toString();

    return AppRemoteConfig(
      maintenanceMode: readBool(data['maintenanceMode'], false),
      maintenanceMessageEn: readString(data['maintenanceMessageEn']),
      maintenanceMessageAr: readString(data['maintenanceMessageAr']),
      minAndroidBuild: readInt(data['minAndroidBuild'], 0),
      minIosBuild: readInt(data['minIosBuild'], 0),
      forceUpdateMessageEn: readString(data['forceUpdateMessageEn']),
      forceUpdateMessageAr: readString(data['forceUpdateMessageAr']),
      androidStoreUrl: readString(data['androidStoreUrl']),
      iosStoreUrl: readString(data['iosStoreUrl']),
      aboutEn: readString(data['aboutEn']),
      aboutAr: readString(data['aboutAr']),
      contactEn: readString(data['contactEn']),
      contactAr: readString(data['contactAr']),
      privacyEn: readString(data['privacyEn']),
      privacyAr: readString(data['privacyAr']),
      termsEn: readString(data['termsEn']),
      termsAr: readString(data['termsAr']),
      referralEnabled: readBool(data['referralEnabled'], false),
      referralRewardReferrerIqd: readInt(data['referralRewardReferrerIqd'], 0),
      referralRewardNewUserIqd: readInt(data['referralRewardNewUserIqd'], 0),
      complaintFlagThreshold: readInt(data['complaintFlagThreshold'], 3),
    );
  }

  Map<String, dynamic> toMap() => {
        'maintenanceMode': maintenanceMode,
        'maintenanceMessageEn': maintenanceMessageEn,
        'maintenanceMessageAr': maintenanceMessageAr,
        'minAndroidBuild': minAndroidBuild,
        'minIosBuild': minIosBuild,
        'forceUpdateMessageEn': forceUpdateMessageEn,
        'forceUpdateMessageAr': forceUpdateMessageAr,
        'androidStoreUrl': androidStoreUrl,
        'iosStoreUrl': iosStoreUrl,
        'aboutEn': aboutEn,
        'aboutAr': aboutAr,
        'contactEn': contactEn,
        'contactAr': contactAr,
        'privacyEn': privacyEn,
        'privacyAr': privacyAr,
        'termsEn': termsEn,
        'termsAr': termsAr,
        'referralEnabled': referralEnabled,
        'referralRewardReferrerIqd': referralRewardReferrerIqd,
        'referralRewardNewUserIqd': referralRewardNewUserIqd,
        'complaintFlagThreshold': complaintFlagThreshold,
      };

  AppRemoteConfig copyWith({
    bool? maintenanceMode,
    String? maintenanceMessageEn,
    String? maintenanceMessageAr,
    int? minAndroidBuild,
    int? minIosBuild,
    String? forceUpdateMessageEn,
    String? forceUpdateMessageAr,
    String? androidStoreUrl,
    String? iosStoreUrl,
    String? aboutEn,
    String? aboutAr,
    String? contactEn,
    String? contactAr,
    String? privacyEn,
    String? privacyAr,
    String? termsEn,
    String? termsAr,
    bool? referralEnabled,
    int? referralRewardReferrerIqd,
    int? referralRewardNewUserIqd,
    int? complaintFlagThreshold,
  }) {
    return AppRemoteConfig(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessageEn: maintenanceMessageEn ?? this.maintenanceMessageEn,
      maintenanceMessageAr: maintenanceMessageAr ?? this.maintenanceMessageAr,
      minAndroidBuild: minAndroidBuild ?? this.minAndroidBuild,
      minIosBuild: minIosBuild ?? this.minIosBuild,
      forceUpdateMessageEn: forceUpdateMessageEn ?? this.forceUpdateMessageEn,
      forceUpdateMessageAr: forceUpdateMessageAr ?? this.forceUpdateMessageAr,
      androidStoreUrl: androidStoreUrl ?? this.androidStoreUrl,
      iosStoreUrl: iosStoreUrl ?? this.iosStoreUrl,
      aboutEn: aboutEn ?? this.aboutEn,
      aboutAr: aboutAr ?? this.aboutAr,
      contactEn: contactEn ?? this.contactEn,
      contactAr: contactAr ?? this.contactAr,
      privacyEn: privacyEn ?? this.privacyEn,
      privacyAr: privacyAr ?? this.privacyAr,
      termsEn: termsEn ?? this.termsEn,
      termsAr: termsAr ?? this.termsAr,
      referralEnabled: referralEnabled ?? this.referralEnabled,
      referralRewardReferrerIqd:
          referralRewardReferrerIqd ?? this.referralRewardReferrerIqd,
      referralRewardNewUserIqd:
          referralRewardNewUserIqd ?? this.referralRewardNewUserIqd,
      complaintFlagThreshold:
          complaintFlagThreshold ?? this.complaintFlagThreshold,
    );
  }
}
