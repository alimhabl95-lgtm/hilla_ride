import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/chat_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/chat_service.dart';
import 'package:hilla_ride/core/utils/voice_recording_format.dart';
import 'package:hilla_ride/features/shared/widgets/voice_message_bubble.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class RideChatScreen extends StatefulWidget {
  const RideChatScreen({
    super.key,
    required this.rideId,
    required this.currentUserId,
    required this.currentUserRole,
    required this.currentUserName,
  });

  static String? foregroundRideId;

  final String rideId;
  final String currentUserId;
  final UserRole currentUserRole;
  final String currentUserName;

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  final _recordingStopwatch = Stopwatch();
  final _uuid = const Uuid();
  final _recordingFormat = VoiceRecordingFormat.forPlatform();

  var _sending = false;
  var _isRecording = false;
  var _recordingElapsedMs = 0;
  Timer? _recordingUiTimer;
  String? _activeRecordingPath;

  static const _maxRecordingDuration = Duration(seconds: 60);
  static const _minRecordingDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    RideChatScreen.foregroundRideId = widget.rideId;
  }

  @override
  void dispose() {
    if (RideChatScreen.foregroundRideId == widget.rideId) {
      RideChatScreen.foregroundRideId = null;
    }
    _recordingUiTimer?.cancel();
    _recordingStopwatch.stop();
    unawaited(_recorder.dispose());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText(ChatService chatService) async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending || _isRecording) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _sending = true);
    try {
      await chatService.sendRideMessage(
        rideId: widget.rideId,
        senderId: widget.currentUserId,
        senderRole: widget.currentUserRole,
        senderName: widget.currentUserName,
        text: text,
      );
      _controller.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.messageSendFailed}\n$error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _ensureMicPermission() async {
    if (kIsWeb) {
      final allowed = await _recorder.hasPermission();
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.microphonePermissionWebHint),
          ),
        );
      }
      return allowed;
    }

    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (await _recorder.hasPermission()) return true;

    if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.microphonePermissionRequired),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return false;
  }

  Future<void> _toggleRecording() async {
    if (_sending) return;

    if (_isRecording) {
      await _stopRecording(send: true);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final allowed = await _ensureMicPermission();
    if (!allowed) {
      if (!mounted) return;
      if (!kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.microphonePermissionRequired)),
        );
      }
      return;
    }

    await _startRecording();
  }

  Future<void> _startRecording() async {
    if (_sending || _isRecording) return;

    final l10n = AppLocalizations.of(context)!;

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }

      var path = '';
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        path =
            '${directory.path}/ride_voice_${DateTime.now().millisecondsSinceEpoch}.${_recordingFormat.extension}';
      }

      await _recorder.start(_recordingFormat.toConfig(), path: path);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!await _recorder.isRecording()) {
        throw StateError('recorder_not_started');
      }

      _activeRecordingPath = path;
      _recordingStopwatch
        ..reset()
        ..start();

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingElapsedMs = 0;
      });

      _recordingUiTimer?.cancel();
      _recordingUiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || !_isRecording) return;
        final elapsedMs = _recordingStopwatch.elapsedMilliseconds;
        setState(() => _recordingElapsedMs = elapsedMs);
        if (elapsedMs >= _maxRecordingDuration.inMilliseconds) {
          unawaited(_stopRecording(send: true));
        }
      });
    } catch (error) {
      _recordingStopwatch.stop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.voiceMessageSendFailed}\n$error')),
      );
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    if (!_isRecording) return;

    _recordingUiTimer?.cancel();
    _recordingUiTimer = null;
    _recordingStopwatch.stop();
    final elapsedMs = _recordingStopwatch.elapsedMilliseconds;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = _activeRecordingPath;
    }
    _activeRecordingPath = null;

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingElapsedMs = 0;
      });
    }

    if (!send || path == null || path.isEmpty) return;
    if (elapsedMs < _minRecordingDuration.inMilliseconds) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.voiceMessageTooShort),
        ),
      );
      return;
    }

    await _sendVoice(path, elapsedMs);
  }

  Future<Uint8List> _readRecordingBytes(String path) async {
    try {
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {
      // Fall through to explicit error below.
    }

    throw StateError('empty_recording');
  }

  Future<void> _sendVoice(String path, int durationMs) async {
    if (_sending) return;

    final l10n = AppLocalizations.of(context)!;
    final chatService = context.read<AppState>().chatService;
    final storageService = context.read<AppState>().storageService;

    setState(() => _sending = true);
    try {
      final bytes = await _readRecordingBytes(path);
      final messageId = _uuid.v4();
      final voiceUrl = await storageService.uploadRideVoiceMessage(
        rideId: widget.rideId,
        messageId: messageId,
        bytes: bytes,
        fileExtension: _recordingFormat.extension,
        contentType: _recordingFormat.contentType,
      );
      await chatService.sendRideVoiceMessage(
        rideId: widget.rideId,
        senderId: widget.currentUserId,
        senderRole: widget.currentUserRole,
        senderName: widget.currentUserName,
        voiceUrl: voiceUrl,
        voiceDurationMs: durationMs,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.voiceMessageSendFailed}\n$error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildComposer(BuildContext context, ChatService chatService) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canSendText =
        !_sending && !_isRecording && _controller.text.trim().isNotEmpty;

    return Material(
      elevation: 6,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.recordingVoice} '
                          '${VoiceMessageBubble.formatDuration(_recordingElapsedMs)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _stopRecording(send: false),
                        child: Text(l10n.cancel),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _controller,
                enabled: !_isRecording && !_sending,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendText(chatService),
                decoration: InputDecoration(
                  hintText: l10n.typeMessage,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Tooltip(
                    message: _isRecording
                        ? l10n.stopRecording
                        : l10n.tapToRecordVoice,
                    child: IconButton.filledTonal(
                      onPressed:
                          (_sending && !_isRecording) ? null : _toggleRecording,
                      icon: Icon(
                        _isRecording ? Icons.stop_circle : Icons.mic,
                        color: _isRecording ? Colors.red : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isRecording ? l10n.stopRecording : l10n.tapToRecordVoice,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: canSendText ? () => _sendText(chatService) : null,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.send, size: 18),
                              const SizedBox(width: 6),
                              Text(l10n.sendAnnouncement),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chatService = context.read<AppState>().chatService;
    final title = widget.currentUserRole == UserRole.customer
        ? l10n.chatWithDriver
        : l10n.chatWithCustomer;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<RideMessage>>(
              stream: chatService.watchRideMessages(widget.rideId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${l10n.chatLoadFailed}\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? const [];
                _scrollToBottom();

                if (messages.isEmpty) {
                  return Center(child: Text(l10n.noChatMessages));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == widget.currentUserId;
                    final time = message.createdAt;
                    final timeLabel = time == null
                        ? ''
                        : DateFormat.Hm(l10n.localeName).format(time);

                    return Align(
                      alignment: isMine
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: message.isVoice
                            ? VoiceMessageBubble(
                                voiceUrl: message.voiceUrl,
                                durationMs: message.voiceDurationMs,
                                isMine: isMine,
                                timeLabel: timeLabel,
                                senderName: message.senderName,
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMine)
                                    Text(
                                      message.senderName,
                                      style:
                                          Theme.of(context).textTheme.labelSmall,
                                    ),
                                  Text(message.text),
                                  if (timeLabel.isNotEmpty)
                                    Text(
                                      timeLabel,
                                      style:
                                          Theme.of(context).textTheme.labelSmall,
                                    ),
                                ],
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildComposer(context, chatService),
        ],
      ),
    );
  }
}
