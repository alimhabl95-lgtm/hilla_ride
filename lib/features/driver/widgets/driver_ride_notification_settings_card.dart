import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/services/driver_ride_alert_settings.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';

/// Driver Settings: ride-request sound, volume, tone, and vibration.
class DriverRideNotificationSettingsCard extends StatefulWidget {
  const DriverRideNotificationSettingsCard({super.key});

  @override
  State<DriverRideNotificationSettingsCard> createState() =>
      _DriverRideNotificationSettingsCardState();
}

class _DriverRideNotificationSettingsCardState
    extends State<DriverRideNotificationSettingsCard> {
  DriverRideAlertSettings _settings = DriverRideAlertSettings.defaults;
  var _ready = false;
  var _previewing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await DriverRideAlertSettings.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _ready = true;
    });
  }

  Future<void> _update(DriverRideAlertSettings next) async {
    setState(() => _settings = next);
    await next.save();
  }

  Future<void> _preview() async {
    if (_previewing) return;
    setState(() => _previewing = true);
    try {
      await NotificationService.previewRideAlert(_settings);
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode.startsWith('ar');
    String t(String ar, String en) => isAr ? ar : en;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('إعدادات تنبيه الرحلة', 'Ride notification settings'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppBrandAssets.brandNavy,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            t(
              'الصوت ومستوى الصوت ونغمة التنبيه والاهتزاز عند وصول رحلة.',
              'Sound, volume, tone, and vibration when a ride arrives.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppBrandAssets.brandMuted,
                ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('الصوت', 'Sound')),
            value: _settings.soundEnabled,
            onChanged: _ready
                ? (value) => _update(_settings.copyWith(soundEnabled: value))
                : null,
          ),
          Text(
            t('مستوى الصوت', 'Volume'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<RideAlertVolume>(
            segments: [
              ButtonSegment(
                value: RideAlertVolume.low,
                label: Text(t('منخفض', 'Low')),
              ),
              ButtonSegment(
                value: RideAlertVolume.medium,
                label: Text(t('متوسط', 'Medium')),
              ),
              ButtonSegment(
                value: RideAlertVolume.high,
                label: Text(t('عالٍ', 'High')),
              ),
            ],
            selected: {_settings.volume},
            onSelectionChanged: _ready
                ? (value) => _update(_settings.copyWith(volume: value.first))
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            t('نغمة التنبيه', 'Notification tone'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<RideAlertTone>(
            segments: [
              ButtonSegment(
                value: RideAlertTone.tone1,
                label: Text(t('النغمة 1', 'Tone 1')),
              ),
              ButtonSegment(
                value: RideAlertTone.tone2,
                label: Text(t('النغمة 2', 'Tone 2')),
              ),
            ],
            selected: {_settings.tone},
            onSelectionChanged: _ready
                ? (value) => _update(_settings.copyWith(tone: value.first))
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('الاهتزاز', 'Vibration')),
            value: _settings.vibrationEnabled,
            onChanged: _ready
                ? (value) =>
                    _update(_settings.copyWith(vibrationEnabled: value))
                : null,
          ),
          const SizedBox(height: 8),
          AppSecondaryButton(
            label: t('تجربة الصوت', 'Preview / Test sound'),
            icon: Icons.volume_up_outlined,
            isLoading: _previewing,
            onPressed: _ready && !_previewing ? _preview : null,
          ),
        ],
      ),
    );
  }
}
