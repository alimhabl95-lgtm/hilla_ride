import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/utils/native_mobile_platform.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/announcement_icon.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Android driver idle dashboard — announcement carousel (no admin label).
class DriverDashboardAnnouncementsCard extends StatefulWidget {
  const DriverDashboardAnnouncementsCard({super.key});

  static bool get isSupported => isNativeMobileApp;

  @override
  State<DriverDashboardAnnouncementsCard> createState() =>
      _DriverDashboardAnnouncementsCardState();
}

class _DriverDashboardAnnouncementsCardState
    extends State<DriverDashboardAnnouncementsCard> {
  final PageController _pageController = PageController();
  Timer? _autoAdvance;
  int _page = 0;
  int _lastSlideCount = 0;

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleAutoAdvance(int count) {
    _autoAdvance?.cancel();
    if (count <= 1) return;
    _autoAdvance = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_page + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!DriverDashboardAnnouncementsCard.isSupported) {
      return const SizedBox.shrink();
    }

    final service = context.read<AppState>().announcementService;

    return StreamBuilder<List<Announcement>>(
      stream: service.watchDriverDashboardAnnouncements(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        final slides = items.take(5).toList();
        if (slides.isEmpty) {
          return const _DefaultAnnouncementCarousel();
        }
        if (_lastSlideCount != slides.length) {
          _lastSlideCount = slides.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scheduleAutoAdvance(slides.length);
          });
        }

        return Column(
          children: [
            SizedBox(
              height: 132,
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  return _AnnouncementSlide(item: slides[index]);
                },
              ),
            ),
            if (slides.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slides.length; i++)
                    Container(
                      width: i == _page ? 10 : 7,
                      height: i == _page ? 10 : 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? AppBrandAssets.brandTeal
                            : AppBrandAssets.brandMuted
                                .withValues(alpha: 0.35),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AnnouncementSlide extends StatelessWidget {
  const _AnnouncementSlide({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = item.imageUrl?.trim();
    final hasText = item.title.trim().isNotEmpty || item.body.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFFFFF4E5),
            AppBrandAssets.brandGold.withValues(alpha: 0.22),
          ],
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Image.network(
                imageUrl!,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _MegaphoneVisual(iconKey: item.iconKey),
              ),
            )
          else
            _MegaphoneVisual(iconKey: item.iconKey),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: hasText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item.title.trim().isNotEmpty)
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppBrandAssets.brandNavy,
                          ),
                        ),
                      if (item.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppBrandAssets.brandNavy.withValues(alpha: 0.85),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          if (item.id != '_placeholder')
            Icon(
              Icons.chevron_right,
              color: AppBrandAssets.brandGoldDark.withValues(alpha: 0.85),
              size: 28,
            ),
        ],
      ),
    );
  }
}

class _DefaultAnnouncementCarousel extends StatelessWidget {
  const _DefaultAnnouncementCarousel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    return SizedBox(
      height: 132,
      child: _AnnouncementSlide(
        item: Announcement(
          id: '_placeholder',
          audience: 'drivers',
          title: isAr ? 'تنبيهات مهمة' : 'Important updates',
          body: isAr
              ? 'ستظهر هنا الرسائل الجديدة عند نشرها.'
              : 'New messages will show here when they are published.',
          iconKey: 'campaign',
        ),
      ),
    );
  }
}

class _MegaphoneVisual extends StatelessWidget {
  const _MegaphoneVisual({this.iconKey});

  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.campaign_rounded,
            size: 72,
            color: AppBrandAssets.brandDanger.withValues(alpha: 0.92),
          ),
          Positioned(
            right: 6,
            top: 18,
            child: Icon(
              announcementIconData(iconKey),
              size: 22,
              color: AppBrandAssets.brandGoldDark,
            ),
          ),
        ],
      ),
    );
  }
}
