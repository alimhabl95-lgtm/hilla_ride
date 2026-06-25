import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

class PickedImage {
  const PickedImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class PhotoUploadTile extends StatelessWidget {
  const PhotoUploadTile({
    super.key,
    required this.label,
    required this.image,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  final String label;
  final PickedImage? image;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: image == null
                    ? Icon(
                        Icons.add_a_photo_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          image!.bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.pickFromGallery),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(l10n.takePhoto),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<PickedImage?> pickImageFile(
  BuildContext context,
  ImageSource source,
) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;

  return PickedImage(
    bytes: bytes,
    fileName: source == ImageSource.camera ? 'camera.jpg' : 'gallery.jpg',
  );
}
