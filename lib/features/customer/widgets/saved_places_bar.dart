import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Horizontal list of the customer's saved places.
class SavedPlacesBar extends StatefulWidget {
  const SavedPlacesBar({
    super.key,
    required this.onPlaceSelected,
    this.compact = false,
  });

  final ValueChanged<PlaceResult> onPlaceSelected;
  final bool compact;

  @override
  State<SavedPlacesBar> createState() => _SavedPlacesBarState();
}

class _SavedPlacesBarState extends State<SavedPlacesBar> {
  List<SavedPlace> _savedPlaces = const [];
  StreamSubscription<List<SavedPlace>>? _sub;
  String? _uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  void _subscribe() {
    final uid = context.read<AppState>().authService.currentUser?.uid;
    _uid = uid;
    if (uid == null) return;
    _sub = context.read<AppState>().savedPlacesService.watchSavedPlaces(uid).listen(
      (places) {
        if (mounted) setState(() => _savedPlaces = places);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _delete(SavedPlace place) async {
    final uid = _uid;
    if (uid == null) return;
    await context.read<AppState>().savedPlacesService.deleteSavedPlace(
          uid: uid,
          placeId: place.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const SizedBox.shrink();
    if (widget.compact && _savedPlaces.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact)
          Row(
            children: [
              Icon(
                Icons.bookmark,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.savedPlacesTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        if (!widget.compact) const SizedBox(height: 6),
        if (_savedPlaces.isEmpty)
          Text(
            l10n.savedPlacesEmptyHint,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          SizedBox(
            height: widget.compact ? 32 : 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _savedPlaces.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final saved = _savedPlaces[index];
                return InputChip(
                  avatar: const Icon(Icons.place, size: 18),
                  label: Text(
                    saved.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => widget.onPlaceSelected(saved.toPlaceResult()),
                  onDeleted: () => _delete(saved),
                );
              },
            ),
          ),
      ],
    );
  }
}

class SavePlaceButton extends StatefulWidget {
  const SavePlaceButton({super.key, required this.place, this.compact = false});

  final PlaceResult? place;
  final bool compact;

  @override
  State<SavePlaceButton> createState() => _SavePlaceButtonState();
}

class _SavePlaceButtonState extends State<SavePlaceButton> {
  bool? _isSaved;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant SavePlaceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPlace = oldWidget.place;
    final place = widget.place;
    if (oldPlace?.latitude != place?.latitude ||
        oldPlace?.longitude != place?.longitude ||
        oldPlace?.label != place?.label) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final place = widget.place;
    if (place == null) {
      if (mounted) setState(() => _isSaved = null);
      return;
    }
    final saved = await isPlaceSaved(context, place: place);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggle() async {
    final place = widget.place;
    if (place == null || _busy) return;
    setState(() => _busy = true);
    await toggleSavedPlace(context, place: place);
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final uid = context.read<AppState>().authService.currentUser?.uid;
    if (place == null || uid == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final isSaved = _isSaved ?? false;

    return SizedBox(
      width: widget.compact ? 36 : null,
      height: widget.compact ? 36 : null,
      child: IconButton.filledTonal(
        tooltip: isSaved ? l10n.placeRemoveFromSaved : l10n.placeSaveAction,
        visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
        padding: widget.compact ? EdgeInsets.zero : null,
        onPressed: _busy ? null : _toggle,
        icon: _busy
            ? SizedBox(
                width: widget.compact ? 18 : 22,
                height: widget.compact ? 18 : 22,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                size: widget.compact ? 18 : 24,
                color: isSaved ? Theme.of(context).colorScheme.primary : null,
              ),
      ),
    );
  }
}

Future<void> toggleSavedPlace(
  BuildContext context, {
  required PlaceResult place,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final auth = context.read<AppState>().authService.currentUser;
  if (auth == null) return;

  final service = context.read<AppState>().savedPlacesService;
  final existing = await _findSaved(context, auth.uid, place);

  try {
    if (existing != null) {
      await service.deleteSavedPlace(uid: auth.uid, placeId: existing.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.placeRemovedFromSaved)),
      );
    } else {
      await service.addSavedPlace(
        uid: auth.uid,
        label: place.label,
        latitude: place.latitude,
        longitude: place.longitude,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.placeSaved)),
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')),
    );
  }
}

Future<bool> isPlaceSaved(
  BuildContext context, {
  required PlaceResult place,
}) async {
  final auth = context.read<AppState>().authService.currentUser;
  if (auth == null) return false;
  final saved = await _findSaved(context, auth.uid, place);
  return saved != null;
}

Future<SavedPlace?> _findSaved(
  BuildContext context,
  String uid,
  PlaceResult place,
) async {
  final key =
      '${place.latitude.toStringAsFixed(4)},${place.longitude.toStringAsFixed(4)}';
  final list = await context.read<AppState>().savedPlacesService.getSavedPlaces(uid);
  for (final saved in list) {
    final savedKey =
        '${saved.latitude.toStringAsFixed(4)},${saved.longitude.toStringAsFixed(4)}';
    if (savedKey == key) return saved;
  }
  return null;
}
