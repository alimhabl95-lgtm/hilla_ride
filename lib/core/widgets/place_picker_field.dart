import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:hilla_ride/features/customer/screens/place_search_screen.dart';

class PlacePickerField extends StatelessWidget {
  const PlacePickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.selectedLabel,
    required this.onPlaceSelected,
    required this.region,
    this.compact = false,
    this.leadingColor,
  });

  final String label;
  final String hint;
  final String? selectedLabel;
  final ValueChanged<PlaceResult> onPlaceSelected;
  final RegionSearchContext region;
  final bool compact;
  final Color? leadingColor;

  Future<void> _openSearch(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final result = await Navigator.of(context, rootNavigator: true).push<PlaceResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PlaceSearchScreen(
          title: label,
          hint: hint,
          initialQuery: selectedLabel ?? '',
          region: region,
        ),
      ),
    );

    if (result != null) {
      onPlaceSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = selectedLabel?.trim();
    final hasValue = value != null && value.isNotEmpty;

    if (compact) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openSearch(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: leadingColor ?? Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      Text(
                        hasValue ? value : hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openSearch(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: const Icon(Icons.chevron_right),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              hasValue ? value : hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasValue ? null : Theme.of(context).hintColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
