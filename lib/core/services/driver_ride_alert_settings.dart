import 'package:shared_preferences/shared_preferences.dart';

enum RideAlertVolume { low, medium, high }

enum RideAlertTone { tone1, tone2 }

class DriverRideAlertSettings {
  const DriverRideAlertSettings({
    required this.soundEnabled,
    required this.volume,
    required this.tone,
    required this.vibrationEnabled,
  });

  final bool soundEnabled;
  final RideAlertVolume volume;
  final RideAlertTone tone;
  final bool vibrationEnabled;

  static const defaults = DriverRideAlertSettings(
    soundEnabled: true,
    volume: RideAlertVolume.high,
    tone: RideAlertTone.tone1,
    vibrationEnabled: true,
  );

  static const _soundKey = 'driver_ride_alert_sound';
  static const _volumeKey = 'driver_ride_alert_volume';
  static const _toneKey = 'driver_ride_alert_tone';
  static const _vibrationKey = 'driver_ride_alert_vibration';

  double get volumeLevel {
    switch (volume) {
      case RideAlertVolume.low:
        return 0.35;
      case RideAlertVolume.medium:
        return 0.65;
      case RideAlertVolume.high:
        return 1;
    }
  }

  String get toneId => tone == RideAlertTone.tone2 ? 'tone2' : 'tone1';

  String get androidSoundName =>
      tone == RideAlertTone.tone2 ? 'ride_alert_chord' : 'ride_alert_loud';

  String get assetPath => tone == RideAlertTone.tone2
      ? 'sounds/ride_alert_chord.wav'
      : 'sounds/ride_alert_loud.wav';

  static Future<DriverRideAlertSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DriverRideAlertSettings(
      soundEnabled: prefs.getBool(_soundKey) ?? true,
      volume: _volumeFrom(prefs.getString(_volumeKey)),
      tone: prefs.getString(_toneKey) == 'tone2'
          ? RideAlertTone.tone2
          : RideAlertTone.tone1,
      vibrationEnabled: prefs.getBool(_vibrationKey) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, soundEnabled);
    await prefs.setString(_volumeKey, volume.name);
    await prefs.setString(_toneKey, toneId);
    await prefs.setBool(_vibrationKey, vibrationEnabled);
  }

  DriverRideAlertSettings copyWith({
    bool? soundEnabled,
    RideAlertVolume? volume,
    RideAlertTone? tone,
    bool? vibrationEnabled,
  }) {
    return DriverRideAlertSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      volume: volume ?? this.volume,
      tone: tone ?? this.tone,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  static RideAlertVolume _volumeFrom(String? value) {
    switch (value) {
      case 'low':
        return RideAlertVolume.low;
      case 'medium':
        return RideAlertVolume.medium;
      default:
        return RideAlertVolume.high;
    }
  }
}
