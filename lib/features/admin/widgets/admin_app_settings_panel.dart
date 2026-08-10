import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_config_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminAppSettingsPanel extends StatefulWidget {
  const AdminAppSettingsPanel({super.key});

  @override
  State<AdminAppSettingsPanel> createState() => _AdminAppSettingsPanelState();
}

class _AdminAppSettingsPanelState extends State<AdminAppSettingsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<AppRemoteConfig>? _configSubscription;

  var _isLoading = true;
  var _isSaving = false;
  var _maintenanceMode = false;
  var _referralEnabled = false;

  final _maintenanceMessageEn = TextEditingController();
  final _maintenanceMessageAr = TextEditingController();
  final _minAndroidBuild = TextEditingController(text: '0');
  final _minIosBuild = TextEditingController(text: '0');
  final _forceUpdateMessageEn = TextEditingController();
  final _forceUpdateMessageAr = TextEditingController();
  final _androidStoreUrl = TextEditingController();
  final _iosStoreUrl = TextEditingController();
  final _aboutEn = TextEditingController();
  final _aboutAr = TextEditingController();
  final _contactEn = TextEditingController();
  final _contactAr = TextEditingController();
  final _privacyEn = TextEditingController();
  final _privacyAr = TextEditingController();
  final _termsEn = TextEditingController();
  final _termsAr = TextEditingController();
  final _referralRewardReferrerIqd = TextEditingController(text: '0');
  final _referralRewardNewUserIqd = TextEditingController(text: '0');
  final _complaintFlagThreshold = TextEditingController(text: '3');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _startWatching();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _tabController.dispose();
    _maintenanceMessageEn.dispose();
    _maintenanceMessageAr.dispose();
    _minAndroidBuild.dispose();
    _minIosBuild.dispose();
    _forceUpdateMessageEn.dispose();
    _forceUpdateMessageAr.dispose();
    _androidStoreUrl.dispose();
    _iosStoreUrl.dispose();
    _aboutEn.dispose();
    _aboutAr.dispose();
    _contactEn.dispose();
    _contactAr.dispose();
    _privacyEn.dispose();
    _privacyAr.dispose();
    _termsEn.dispose();
    _termsAr.dispose();
    _referralRewardReferrerIqd.dispose();
    _referralRewardNewUserIqd.dispose();
    _complaintFlagThreshold.dispose();
    super.dispose();
  }

  void _startWatching() {
    _configSubscription?.cancel();
    _configSubscription = context
        .read<AppState>()
        .appConfigService
        .watchConfig()
        .listen(
      (config) {
        if (!mounted || _isSaving) return;
        _applyConfig(config);
        setState(() => _isLoading = false);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      },
    );
  }

  void _applyConfig(AppRemoteConfig config) {
    _maintenanceMode = config.maintenanceMode;
    _referralEnabled = config.referralEnabled;
    _maintenanceMessageEn.text = config.maintenanceMessageEn;
    _maintenanceMessageAr.text = config.maintenanceMessageAr;
    _minAndroidBuild.text = '${config.minAndroidBuild}';
    _minIosBuild.text = '${config.minIosBuild}';
    _forceUpdateMessageEn.text = config.forceUpdateMessageEn;
    _forceUpdateMessageAr.text = config.forceUpdateMessageAr;
    _androidStoreUrl.text = config.androidStoreUrl;
    _iosStoreUrl.text = config.iosStoreUrl;
    _aboutEn.text = config.aboutEn;
    _aboutAr.text = config.aboutAr;
    _contactEn.text = config.contactEn;
    _contactAr.text = config.contactAr;
    _privacyEn.text = config.privacyEn;
    _privacyAr.text = config.privacyAr;
    _termsEn.text = config.termsEn;
    _termsAr.text = config.termsAr;
    _referralRewardReferrerIqd.text = '${config.referralRewardReferrerIqd}';
    _referralRewardNewUserIqd.text = '${config.referralRewardNewUserIqd}';
    _complaintFlagThreshold.text = '${config.complaintFlagThreshold}';
  }

  AppRemoteConfig _buildConfigFromFields() {
    int parseInt(TextEditingController controller, int fallback) =>
        int.tryParse(controller.text.trim()) ?? fallback;

    return AppRemoteConfig(
      maintenanceMode: _maintenanceMode,
      maintenanceMessageEn: _maintenanceMessageEn.text.trim(),
      maintenanceMessageAr: _maintenanceMessageAr.text.trim(),
      minAndroidBuild: parseInt(_minAndroidBuild, 0),
      minIosBuild: parseInt(_minIosBuild, 0),
      forceUpdateMessageEn: _forceUpdateMessageEn.text.trim(),
      forceUpdateMessageAr: _forceUpdateMessageAr.text.trim(),
      androidStoreUrl: _androidStoreUrl.text.trim(),
      iosStoreUrl: _iosStoreUrl.text.trim(),
      aboutEn: _aboutEn.text.trim(),
      aboutAr: _aboutAr.text.trim(),
      contactEn: _contactEn.text.trim(),
      contactAr: _contactAr.text.trim(),
      privacyEn: _privacyEn.text.trim(),
      privacyAr: _privacyAr.text.trim(),
      termsEn: _termsEn.text.trim(),
      termsAr: _termsAr.text.trim(),
      referralEnabled: _referralEnabled,
      referralRewardReferrerIqd: parseInt(_referralRewardReferrerIqd, 0),
      referralRewardNewUserIqd: parseInt(_referralRewardNewUserIqd, 0),
      complaintFlagThreshold: parseInt(_complaintFlagThreshold, 3),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final appState = context.read<AppState>();
    final isAr = AppLocalizations.of(context)!.localeName.startsWith('ar');
    try {
      final adminUser = await appState.authService.getCurrentProfile();
      await appState.appConfigService.saveAppConfig(
            _buildConfigFromFields(),
            adminUser: adminUser,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم حفظ إعدادات التطبيق' : 'App settings saved',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context)!.localeName.startsWith('ar');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [
              Tab(text: isAr ? 'الصيانة' : 'Maintenance'),
              Tab(text: isAr ? 'التحديث' : 'Force update'),
              Tab(text: isAr ? 'قانوني / حول' : 'Legal / About'),
              Tab(text: isAr ? 'الإحالة' : 'Referral'),
              Tab(text: isAr ? 'الشكاوى' : 'Complaints'),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _maintenanceTab(isAr),
                    _forceUpdateTab(isAr),
                    _legalTab(isAr),
                    _referralTab(isAr),
                    _complaintsTab(isAr),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(isAr ? 'حفظ الإعدادات' : 'Save settings'),
          ),
        ),
      ],
    );
  }

  Widget _maintenanceTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SwitchListTile(
          title: Text(isAr ? 'وضع الصيانة' : 'Maintenance mode'),
          subtitle: Text(
            isAr
                ? 'يمنع العملاء والسائقين من استخدام التطبيق'
                : 'Blocks customers and drivers from using the app',
          ),
          value: _maintenanceMode,
          onChanged: (value) => setState(() => _maintenanceMode = value),
        ),
        _textField(
          isAr ? 'رسالة الصيانة (EN)' : 'Maintenance message (EN)',
          _maintenanceMessageEn,
          maxLines: 4,
        ),
        _textField(
          isAr ? 'رسالة الصيانة (AR)' : 'Maintenance message (AR)',
          _maintenanceMessageAr,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _forceUpdateTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _textField(
          isAr ? 'أدنى build لأندرويد' : 'Min Android build',
          _minAndroidBuild,
        ),
        _textField(
          isAr ? 'أدنى build لـ iOS' : 'Min iOS build',
          _minIosBuild,
        ),
        _textField(
          isAr ? 'رسالة التحديث (EN)' : 'Force update message (EN)',
          _forceUpdateMessageEn,
          maxLines: 3,
        ),
        _textField(
          isAr ? 'رسالة التحديث (AR)' : 'Force update message (AR)',
          _forceUpdateMessageAr,
          maxLines: 3,
        ),
        _textField(
          isAr ? 'رابط متجر أندرويد' : 'Android store URL',
          _androidStoreUrl,
        ),
        _textField(
          isAr ? 'رابط متجر iOS' : 'iOS store URL',
          _iosStoreUrl,
        ),
      ],
    );
  }

  Widget _legalTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _textField(isAr ? 'حول (EN)' : 'About (EN)', _aboutEn, maxLines: 6),
        _textField(isAr ? 'حول (AR)' : 'About (AR)', _aboutAr, maxLines: 6),
        _textField(
          isAr ? 'اتصل بنا (EN)' : 'Contact (EN)',
          _contactEn,
          maxLines: 6,
        ),
        _textField(
          isAr ? 'اتصل بنا (AR)' : 'Contact (AR)',
          _contactAr,
          maxLines: 6,
        ),
        _textField(
          isAr ? 'الخصوصية (EN)' : 'Privacy (EN)',
          _privacyEn,
          maxLines: 8,
        ),
        _textField(
          isAr ? 'الخصوصية (AR)' : 'Privacy (AR)',
          _privacyAr,
          maxLines: 8,
        ),
        _textField(
          isAr ? 'الشروط (EN)' : 'Terms (EN)',
          _termsEn,
          maxLines: 8,
        ),
        _textField(
          isAr ? 'الشروط (AR)' : 'Terms (AR)',
          _termsAr,
          maxLines: 8,
        ),
      ],
    );
  }

  Widget _referralTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SwitchListTile(
          title: Text(isAr ? 'تفعيل الإحالة' : 'Referral enabled'),
          value: _referralEnabled,
          onChanged: (value) => setState(() => _referralEnabled = value),
        ),
        _textField(
          isAr ? 'مكافأة المُحيل (IQD)' : 'Referrer reward (IQD)',
          _referralRewardReferrerIqd,
        ),
        _textField(
          isAr ? 'مكافأة المستخدم الجديد (IQD)' : 'New user reward (IQD)',
          _referralRewardNewUserIqd,
        ),
      ],
    );
  }

  Widget _complaintsTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _textField(
          isAr ? 'حد علم الشكاوى' : 'Complaint flag threshold',
          _complaintFlagThreshold,
        ),
        Text(
          isAr
              ? 'عدد الشكاوى قبل وضع علامة على السائق (افتراضي 3)'
              : 'Number of complaints before flagging a driver (default 3)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
