import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/config/app_variant.dart';
import 'package:hilla_ride/core/models/app_config_models.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/legal_url_launcher.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class AppGate extends StatefulWidget {
  const AppGate({
    super.key,
    required this.child,
    this.bypassGate = false,
  });

  final Widget child;
  final bool bypassGate;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  PackageInfo? _packageInfo;
  var _forceUpdateDialogShown = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      PackageInfo.fromPlatform().then((info) {
        if (mounted) setState(() => _packageInfo = info);
      });
    }
  }

  bool _isAdminBypass(AppUser? profile) {
    if (widget.bypassGate || AppConfig.variant.isWebAdmin) return true;
    if (profile == null) return false;
    return profile.role == UserRole.manager || profile.role == UserRole.assistant;
  }

  int? _currentBuildNumber() {
    final buildText = _packageInfo?.buildNumber;
    if (buildText == null || buildText.isEmpty) return null;
    return int.tryParse(buildText);
  }

  bool _needsForceUpdate(AppRemoteConfig config) {
    if (kIsWeb) return false;
    final currentBuild = _currentBuildNumber();
    if (currentBuild == null) return false;

    if (!kIsWeb && Platform.isAndroid) {
      return config.minAndroidBuild > 0 && currentBuild < config.minAndroidBuild;
    }
    if (!kIsWeb && Platform.isIOS) {
      return config.minIosBuild > 0 && currentBuild < config.minIosBuild;
    }
    return false;
  }

  String _storeUrl(AppRemoteConfig config) {
    if (!kIsWeb && Platform.isIOS) {
      return config.iosStoreUrl;
    }
    return config.androidStoreUrl;
  }

  Future<void> _showForceUpdateDialog(AppRemoteConfig config) async {
    if (!mounted || _forceUpdateDialogShown) return;
    _forceUpdateDialogShown = true;

    final l10n = AppLocalizations.of(context)!;
    final lang = l10n.localeName.startsWith('ar') ? 'ar' : 'en';
    final message = config.forceUpdateMessageFor(lang);
    final storeUrl = _storeUrl(config);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(lang == 'ar' ? 'تحديث مطلوب' : 'Update required'),
            content: Text(
              message.isEmpty
                  ? (lang == 'ar'
                      ? 'يرجى تحديث التطبيق للمتابعة.'
                      : 'Please update the app to continue.')
                  : message,
            ),
            actions: [
              if (storeUrl.isNotEmpty)
                FilledButton(
                  onPressed: () => openLegalDocumentUrl(storeUrl),
                  child: Text(lang == 'ar' ? 'تحديث الآن' : 'Update now'),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bypassGate || AppConfig.variant.isWebAdmin) {
      return widget.child;
    }

    final configService = context.read<AppState>().appConfigService;
    final authService = context.read<AppState>().authService;

    return StreamBuilder<AppRemoteConfig>(
      stream: configService.watchConfig(),
      builder: (context, configSnapshot) {
        final config = configSnapshot.data ?? AppRemoteConfig.defaults;

        return StreamBuilder<AppUser?>(
          stream: authService.watchCurrentProfile(),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data;
            final adminBypass = _isAdminBypass(profile);

            if (config.maintenanceMode && !adminBypass) {
              final l10n = AppLocalizations.of(context)!;
              final lang = l10n.localeName.startsWith('ar') ? 'ar' : 'en';
              final message = config.maintenanceMessageFor(lang);
              return _MaintenanceScreen(
                message: message.isEmpty
                    ? (lang == 'ar'
                        ? 'التطبيق تحت الصيانة. يرجى المحاولة لاحقاً.'
                        : 'The app is under maintenance. Please try again later.')
                    : message,
              );
            }

            if (_needsForceUpdate(config)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showForceUpdateDialog(config);
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return widget.child;
          },
        );
      },
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_circle_outlined, size: 72),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
