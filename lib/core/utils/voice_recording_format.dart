import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class VoiceRecordingFormat {
  const VoiceRecordingFormat({
    required this.encoder,
    required this.extension,
    required this.contentType,
    required this.sampleRate,
  });

  final AudioEncoder encoder;
  final String extension;
  final String contentType;
  final int sampleRate;

  RecordConfig toConfig() {
    return RecordConfig(
      encoder: encoder,
      sampleRate: sampleRate,
      numChannels: 1,
      bitRate: 128000,
    );
  }

  static VoiceRecordingFormat forPlatform() {
    if (kIsWeb) {
      // WAV records reliably on iPhone Safari and desktop browsers.
      return const VoiceRecordingFormat(
        encoder: AudioEncoder.wav,
        extension: 'wav',
        contentType: 'audio/wav',
        sampleRate: 16000,
      );
    }

    return const VoiceRecordingFormat(
      encoder: AudioEncoder.aacLc,
      extension: 'm4a',
      contentType: 'audio/mp4',
      sampleRate: 44100,
    );
  }
}
