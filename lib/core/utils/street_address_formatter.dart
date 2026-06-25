/// Builds a short street-focused label from geocoder address components.
class StreetAddressFormatter {
  StreetAddressFormatter._();

  static final RegExp _streetHintPattern = RegExp(
    r'شارع|ش\.|طريق|م\.|س\.|street|st\.|road|rd\.|avenue|ave\.',
    caseSensitive: false,
  );

  static String? fromGoogleGeocodeResults(
    List<dynamic>? results, {
    required bool isArabic,
  }) {
    if (results == null || results.isEmpty) return null;

    String? routeResultLabel;
    String? componentRouteLabel;
    String? formattedSegmentLabel;

    for (final item in results) {
      if (item is! Map<String, dynamic>) continue;
      final types = (item['types'] as List?)?.cast<String>() ?? const [];
      final formatted = item['formatted_address'] as String?;
      final components = item['address_components'] as List<dynamic>?;

      final label = fromGoogleAddressComponents(
        components,
        isArabic: isArabic,
        formattedAddressFallback: formatted,
      );

      final hasRouteComponent = _componentsHaveRoute(components);
      final isRouteResult =
          types.contains('route') || types.contains('street_address');

      if (label != null &&
          label.isNotEmpty &&
          (hasRouteComponent || isRouteResult) &&
          looksLikeStreetName(label)) {
        return label;
      }

      if (isRouteResult && label != null && label.isNotEmpty) {
        routeResultLabel ??= label;
      }

      if (hasRouteComponent && label != null && label.isNotEmpty) {
        componentRouteLabel ??= label;
      }

      final segment = firstStreetLikeSegment(formatted, isArabic: isArabic);
      if (segment != null) {
        formattedSegmentLabel ??= segment;
      }
    }

    for (final candidate in [
      routeResultLabel,
      componentRouteLabel,
      formattedSegmentLabel,
    ]) {
      if (candidate != null &&
          candidate.isNotEmpty &&
          looksLikeStreetName(candidate)) {
        return candidate;
      }
    }

    return routeResultLabel ?? componentRouteLabel ?? formattedSegmentLabel;
  }

  static String? fromGoogleAddressComponents(
    List<dynamic>? components, {
    required bool isArabic,
    String? formattedAddressFallback,
  }) {
    if (components == null || components.isEmpty) {
      return firstStreetLikeSegment(
        formattedAddressFallback,
        isArabic: isArabic,
      );
    }

    String? streetNumber;
    String? route;
    String? neighborhood;
    String? sublocality;
    String? locality;

    for (final item in components) {
      if (item is! Map<String, dynamic>) continue;
      final types = (item['types'] as List?)?.cast<String>() ?? const [];
      final name = (item['long_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;

      if (types.contains('street_number')) streetNumber = name;
      if (types.contains('route')) route = name;
      if (types.contains('neighborhood')) neighborhood = name;
      if (types.contains('sublocality') ||
          types.contains('sublocality_level_1') ||
          types.contains('sublocality_level_2')) {
        sublocality ??= name;
      }
      if (types.contains('locality')) locality = name;
    }

    final area = neighborhood ?? sublocality ?? locality;
    final street = _formatStreetLine(
      route: route,
      streetNumber: streetNumber,
      isArabic: isArabic,
    );

    if (street != null && street.isNotEmpty) {
      return _joinStreetAndArea(street, area, isArabic: isArabic);
    }

    return firstStreetLikeSegment(
      formattedAddressFallback,
      isArabic: isArabic,
    );
  }

  static String? fromNominatimAddress(Map<String, dynamic>? address) {
    if (address == null || address.isEmpty) return null;

    final road = _firstNonEmpty([
      address['road'],
      address['pedestrian'],
      address['footway'],
      address['residential'],
      address['path'],
      address['hamlet'],
    ]);
    final streetNumber = _firstNonEmpty([address['house_number']]);
    final area = _firstNonEmpty([
      address['neighbourhood'],
      address['suburb'],
      address['quarter'],
      address['village'],
      address['town'],
      address['city'],
    ]);

    final street = _formatStreetLine(
      route: road,
      streetNumber: streetNumber,
      isArabic: _looksArabic('$road$streetNumber$area'),
    );
    if (street == null || street.isEmpty) return null;

    return _joinStreetAndArea(
      street,
      area,
      isArabic: _looksArabic('$street$area'),
    );
  }

  static bool looksLikeStreetName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (_streetHintPattern.hasMatch(trimmed)) return true;

    final parts = _splitAddressParts(trimmed);
    if (parts.length >= 2) {
      return looksLikeStreetName(parts.first);
    }

    return trimmed.length > 8;
  }

  static String? firstStreetLikeSegment(
    String? formatted, {
    required bool isArabic,
  }) {
    final parts = _splitAddressParts(formatted);
    if (parts.isEmpty) return null;

    for (final part in parts) {
      if (looksLikeStreetName(part)) {
        final area = parts.length > 1 ? parts[1] : null;
        return _joinStreetAndArea(part, area, isArabic: isArabic);
      }
    }

    if (parts.length >= 2) {
      return _joinStreetAndArea(parts[0], parts[1], isArabic: isArabic);
    }

    return parts.first;
  }

  static bool _componentsHaveRoute(List<dynamic>? components) {
    if (components == null) return false;
    for (final item in components) {
      if (item is! Map<String, dynamic>) continue;
      final types = (item['types'] as List?)?.cast<String>() ?? const [];
      if (types.contains('route')) return true;
    }
    return false;
  }

  static List<String> _splitAddressParts(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return const [];

    final separator = trimmed.contains('،') ? '،' : ',';
    return trimmed
        .split(separator)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static String? _formatStreetLine({
    required String? route,
    required String? streetNumber,
    required bool isArabic,
  }) {
    final street = route?.trim();
    if (street == null || street.isEmpty) return null;

    final number = streetNumber?.trim();
    if (number == null || number.isEmpty) return street;

    return isArabic ? '$street، $number' : '$number $street';
  }

  static String _joinStreetAndArea(
    String street,
    String? area, {
    required bool isArabic,
  }) {
    final trimmedArea = area?.trim();
    if (trimmedArea == null ||
        trimmedArea.isEmpty ||
        street.contains(trimmedArea)) {
      return street;
    }
    return isArabic ? '$street، $trimmedArea' : '$street, $trimmedArea';
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static bool _looksArabic(String value) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(value);
}
