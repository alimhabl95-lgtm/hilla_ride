import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class VoiceMessageBubble extends StatefulWidget {
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

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final _player = AudioPlayer();
  var _isPlaying = false;
  var _isLoading = false;
  var _showPlaybackError = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isLoading || widget.voiceUrl.trim().isEmpty) return;

    if (_isPlaying) {
      await _player.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _showPlaybackError = false;
    });

    try {
      await _player.stop();
      await _player.setVolume(1.0);

      if (!mounted) return;
      final storageService = context.read<AppState>().storageService;
      final bytes = await storageService.downloadRideVoiceMessage(
        voiceUrl: widget.voiceUrl,
      );

      if (bytes != null && bytes.isNotEmpty) {
        await _player.play(BytesSource(bytes));
      } else {
        await _player.play(UrlSource(widget.voiceUrl));
      }

      if (mounted) setState(() => _isPlaying = true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Voice playback failed: $error');
      }
      if (mounted) setState(() => _showPlaybackError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final durationLabel = widget.durationMs > 0
        ? VoiceMessageBubble.formatDuration(widget.durationMs)
        : '--:--';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: _isLoading ? null : _togglePlayback,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isMine && widget.senderName.isNotEmpty)
                Text(
                  widget.senderName,
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
              if (_showPlaybackError)
                Text(
                  l10n.voiceMessagePlaybackFailed,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              if (widget.timeLabel.isNotEmpty)
                Text(
                  widget.timeLabel,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
