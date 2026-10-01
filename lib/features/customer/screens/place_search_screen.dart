import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({
    super.key,
    required this.title,
    required this.hint,
    required this.region,
    this.initialQuery = '',
  });

  final String title;
  final String hint;
  final RegionSearchContext region;
  final String initialQuery;

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  static final RegExp _coordinatePattern = RegExp(r'^-?\d+\.\d+\s*,\s*-?\d+\.\d+');

  static const _categoryFilters = [
    'مستشفى',
    'سوق',
    'جامعة',
    'مسجد',
    'شارع',
    'بنك',
    'مطعم',
  ];

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  List<PlaceResult> _results = const [];
  List<PlaceResult> _suggestedPlaces = const [];
  bool _isSearching = false;
  bool _showNoResults = false;
  Timer? _debounce;
  int _searchGeneration = 0;
  String _activeFilter = '';
  bool _placesBlocked = false;
  List<SavedPlace> _savedPlaces = const [];
  StreamSubscription<List<SavedPlace>>? _savedSub;
  String? _uid;

  String _placeKey(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  SavedPlace? _matchSaved(PlaceResult place) {
    final key = _placeKey(place.latitude, place.longitude);
    for (final saved in _savedPlaces) {
      if (_placeKey(saved.latitude, saved.longitude) == key) {
        return saved;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final initial = _coordinatePattern.hasMatch(widget.initialQuery.trim())
        ? ''
        : widget.initialQuery;
    _controller = TextEditingController(text: initial);
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeSavedPlaces();
      _loadPlaces();
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _subscribeSavedPlaces() {
    final appState = context.read<AppState>();
    final uid = appState.authService.currentUser?.uid;
    _uid = uid;
    if (uid == null) return;
    _savedSub =
        appState.savedPlacesService.watchSavedPlaces(uid).listen((places) {
      if (mounted) setState(() => _savedPlaces = places);
    });
  }

  Future<void> _toggleSave(PlaceResult place) async {
    final uid = _uid;
    if (uid == null) return;
    final l10n = AppLocalizations.of(context)!;
    final savedPlaces = context.read<AppState>().savedPlacesService;
    final existing = _matchSaved(place);

    try {
      if (existing != null) {
        await savedPlaces.deleteSavedPlace(uid: uid, placeId: existing.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.placeRemovedFromSaved)),
        );
      } else {
        await savedPlaces.addSavedPlace(
          uid: uid,
          label: place.label,
          latitude: place.latitude,
          longitude: place.longitude,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.placeSaved)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _deleteSaved(SavedPlace place) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await context
          .read<AppState>()
          .savedPlacesService
          .deleteSavedPlace(uid: uid, placeId: place.id);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _savedSub?.cancel();
    _controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _activeFilter = '';
    setState(() {});
    _scheduleFilter(_controller.text);
  }

  Future<void> _loadPlaces() async {
    setState(() => _isSearching = true);
    try {
      final places = await context
          .read<AppState>()
          .geocodingService
          .listPlacesInRegion(
            widget.region,
            acceptLanguage: AppLocalizations.of(context)!.localeName,
          );
      if (!mounted) return;
      setState(() {
        _suggestedPlaces = places;
        _results = places;
        _isSearching = false;
        _placesBlocked =
            context.read<AppState>().geocodingService.isGooglePlacesBlocked;
      });
      if (widget.initialQuery.trim().isNotEmpty &&
          !_coordinatePattern.hasMatch(widget.initialQuery.trim())) {
        _scheduleFilter(widget.initialQuery);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _scheduleFilter(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _applyFilter(value);
    });
  }

  Future<void> _applyFilter(String value) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _showNoResults = false;
    });

    try {
      final geocoding = context.read<AppState>().geocodingService;
      final l10n = AppLocalizations.of(context)!;
      final trimmed = value.trim();
      List<PlaceResult> results;

      if (trimmed.isEmpty) {
        results = await geocoding.listPlacesInRegion(
          widget.region,
          acceptLanguage: l10n.localeName,
        );
      } else {
        results = await geocoding.searchPlacesInRegion(
          trimmed,
          region: widget.region,
          acceptLanguage: l10n.localeName,
        );
      }

      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _showNoResults = results.isEmpty && trimmed.isNotEmpty;
        _isSearching = false;
        _placesBlocked = geocoding.isGooglePlacesBlocked;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = const [];
        _showNoResults = true;
        _isSearching = false;
      });
    }
  }

  void _selectCategory(String category) {
    _activeFilter = category;
    _controller.text = category;
    _controller.selection = TextSelection.collapsed(offset: category.length);
    _debounce?.cancel();
    _applyFilter(category);
  }

  void _clearQuery() {
    _activeFilter = '';
    _controller.clear();
    _debounce?.cancel();
    _applyFilter('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = l10n.localeName.startsWith('ar');
    final regionLabel = widget.region.label(isArabic: isArabic);

    final query = _controller.text.trim();
    final showingSuggestions = query.isEmpty;
    final visiblePlaces =
        showingSuggestions && _suggestedPlaces.isNotEmpty
            ? _suggestedPlaces
            : _results;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Material(
              elevation: 2,
              shadowColor: AppBrandAssets.brandNavy.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textDirection:
                    isArabic ? TextDirection.rtl : TextDirection.ltr,
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                textInputAction: TextInputAction.search,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppBrandAssets.brandNavy,
                      fontWeight: FontWeight.w600,
                    ),
                decoration: InputDecoration(
                  hintText: widget.hint.isNotEmpty
                      ? widget.hint
                      : l10n.searchFieldHint,
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppBrandAssets.brandMuted,
                      ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppBrandAssets.brandTealDark,
                  ),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearQuery,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                onSubmitted: _applyFilter,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            color: AppBrandAssets.brandSurface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppBrandAssets.brandTealDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.searchRegionHint(regionLabel),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppBrandAssets.brandNavy,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (_placesBlocked && _results.isEmpty && !_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.placesApiDenied,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          if (_uid != null && _controller.text.trim().isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
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
            ),
            if (_savedPlaces.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.savedPlacesEmptyHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      onPressed: () =>
                          Navigator.of(context).pop(saved.toPlaceResult()),
                      onDeleted: () => _deleteSaved(saved),
                    );
                  },
                ),
              ),
          ],
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _categoryFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categoryFilters[index];
                final selected = _activeFilter == category;
                return FilterChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => _selectCategory(category),
                );
              },
            ),
          ),
          if (_isSearching) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              showingSuggestions
                  ? (isArabic
                      ? 'اقتراحات في $regionLabel'
                      : 'Suggested places in $regionLabel')
                  : (isArabic
                      ? 'نتائج البحث (${_results.length})'
                      : 'Search results (${_results.length})'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppBrandAssets.brandNavy,
                  ),
            ),
          ),
          Expanded(
            child: visiblePlaces.isEmpty
                ? Center(
                    child: Text(
                      _showNoResults ? l10n.noPlacesFound : l10n.searchPlaces,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: visiblePlaces.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = visiblePlaces[index];
                      final isSaved = _matchSaved(place) != null;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        leading: const Icon(
                          Icons.place,
                          color: AppBrandAssets.brandTealDark,
                        ),
                        title: Text(
                          place.label,
                          textDirection:
                              isArabic ? TextDirection.rtl : TextDirection.ltr,
                          textAlign:
                              isArabic ? TextAlign.right : TextAlign.left,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: _uid == null
                            ? const Icon(Icons.chevron_right)
                            : IconButton(
                                tooltip: isSaved
                                    ? l10n.placeRemoveFromSaved
                                    : l10n.savePlaceShort,
                                onPressed: () => _toggleSave(place),
                                icon: Icon(
                                  isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: isSaved
                                      ? Theme.of(context).colorScheme.primary
                                      : AppBrandAssets.brandTealDark,
                                ),
                              ),
                        onTap: () => Navigator.of(context).pop(place),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
