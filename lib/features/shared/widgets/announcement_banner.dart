import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({
    super.key,
    required this.audience,
  });

  final String audience;

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  final _dismissedIds = <String>{};
  var _loadedDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'dismissed_banner_ids_${widget.audience}';
    final ids = prefs.getStringList(key) ?? const [];
    if (!mounted) return;
    setState(() {
      _dismissedIds
        ..clear()
        ..addAll(ids);
      _loadedDismissed = true;
    });
  }

  Future<void> _dismiss(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'dismissed_banner_ids_${widget.audience}';
    _dismissedIds.add(id);
    await prefs.setStringList(key, _dismissedIds.toList());
    if (mounted) setState(() {});
  }

  Announcement? _pickBanner(List<Announcement> items) {
    for (final item in items) {
      if (item.title.trim().isEmpty) continue;
      if (!_dismissedIds.contains(item.id)) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedDismissed) {
      return const SizedBox.shrink();
    }

    final configService = context.read<AppState>().appConfigService;

    return StreamBuilder<List<Announcement>>(
      stream: configService.watchActiveBanners(widget.audience),
      builder: (context, snapshot) {
        final banner = _pickBanner(snapshot.data ?? const []);
        if (banner == null) return const SizedBox.shrink();

        return Material(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banner.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (banner.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            banner.body,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                    onPressed: () => _dismiss(banner.id),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
