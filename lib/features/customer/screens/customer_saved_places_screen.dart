import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class CustomerSavedPlacesScreen extends StatelessWidget {
  const CustomerSavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final uid = context.read<AppState>().authService.currentUser?.uid;
    final service = context.read<AppState>().savedPlacesService;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'الأماكن المحفوظة' : 'Saved places'),
      ),
      body: uid == null
          ? Center(child: Text(isAr ? 'يلزم تسجيل الدخول' : 'Sign in required'))
          : StreamBuilder<List<SavedPlace>>(
              stream: service.watchSavedPlaces(uid),
              builder: (context, snapshot) {
                final places = snapshot.data ?? const <SavedPlace>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (places.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isAr
                            ? 'احفظ الأماكن من البحث لاستخدامها لاحقاً.'
                            : 'Save places from search to reuse them quickly.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: places.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place.label),
                      subtitle: Text(
                        '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => service.deleteSavedPlace(
                          uid: uid,
                          placeId: place.id,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
