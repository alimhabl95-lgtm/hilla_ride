import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:provider/provider.dart';

class FirebaseDriverPhotoImage extends StatefulWidget {
  const FirebaseDriverPhotoImage({
    super.key,
    required this.driverId,
    required this.fileName,
    this.imageUrl = '',
    this.fit = BoxFit.cover,
    this.forAdmin = false,
  });

  final String driverId;
  final String fileName;
  final String imageUrl;
  final BoxFit fit;
  final bool forAdmin;

  @override
  State<FirebaseDriverPhotoImage> createState() =>
      _FirebaseDriverPhotoImageState();
}

class _FirebaseDriverPhotoImageState extends State<FirebaseDriverPhotoImage> {
  Future<Uint8List?>? _bytesFuture;
  String? _cacheKey;

  void _refresh() {
    setState(() {
      _cacheKey = null;
      _bytesFuture = null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cacheKey =
        '${widget.driverId}|${widget.fileName}|${widget.imageUrl}';
    if (_cacheKey == cacheKey) return;

    _cacheKey = cacheKey;
    _bytesFuture = context.read<AppState>().storageService.loadDriverPhotoBytes(
          driverId: widget.driverId,
          fileName: widget.fileName,
          imageUrl: widget.imageUrl,
          forAdmin: widget.forAdmin,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.trim().isNotEmpty && !widget.forAdmin && !kIsWeb) {
      return Image.network(
        widget.imageUrl,
        fit: widget.fit,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint('Driver photo network load failed: $error');
          }
          return _BytesPhoto(
            bytesFuture: _bytesFuture,
            fit: widget.fit,
            onRetry: _refresh,
          );
        },
      );
    }

    return _BytesPhoto(
      bytesFuture: _bytesFuture,
      fit: widget.fit,
      onRetry: _refresh,
    );
  }
}

class _BytesPhoto extends StatelessWidget {
  const _BytesPhoto({
    required this.bytesFuture,
    required this.fit,
    required this.onRetry,
  });

  final Future<Uint8List?>? bytesFuture;
  final BoxFit fit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('Driver photo load failed: ${snapshot.error}');
          }
          return _PhotoError(onRetry: onRetry);
        }

        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return _PhotoError(onRetry: onRetry);
        }

        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              debugPrint('Driver photo render failed: $error');
            }
            return _PhotoError(onRetry: onRetry);
          },
        );
      },
    );
  }
}

class _PhotoError extends StatelessWidget {
  const _PhotoError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 36,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 8),
          IconButton(
            tooltip: 'Retry',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

void showDriverPhotoPreview(
  BuildContext context, {
  required String driverId,
  required String fileName,
  required String imageUrl,
  required String title,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.9,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(title: Text(title)),
            Expanded(
              child: InteractiveViewer(
                child: FirebaseDriverPhotoImage(
                  driverId: driverId,
                  fileName: fileName,
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  forAdmin: true,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
