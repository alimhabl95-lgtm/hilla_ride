import 'package:flutter/material.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';

class VoiceMessageBubble extends StatelessWidget {
  const VoiceMessageBubble({
    super.key,
    required this.voiceUrl,
    required this.durationMs,
    required this.isMine,
    required this.timeLabel,
    required this.senderName,
  });

  final String voiceUrl;
  final int durationMs;
  final bool isMine;
  final String timeLabel;
  final String senderName;

  static String formatDuration(int durationMs) {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _showPlaybackUnavailable(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.voiceMessagePlaybackFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final durationLabel = durationMs > 0
        ? VoiceMessageBubble.formatDuration(durationMs)
        : '--:--';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: voiceUrl.trim().isEmpty
              ? null
              : () => _showPlaybackUnavailable(context),
          icon: Icon(
            Icons.play_circle,
            color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine && senderName.isNotEmpty)
                Text(
                  senderName,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              Text(
                l10n.voiceMessageLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                durationLabel,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (timeLabel.isNotEmpty)
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
