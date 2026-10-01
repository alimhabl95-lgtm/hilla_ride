import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/utils/native_mobile_platform.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Compact management ads / notices bar on the Android customer home card.
class CustomerDashboardAdsBar extends StatefulWidget {
  const CustomerDashboardAdsBar({super.key});

  static bool get isSupported => isNativeMobileApp;

  @override
  State<CustomerDashboardAdsBar> createState() =>
      _CustomerDashboardAdsBarState();
}

class _CustomerDashboardAdsBarState extends State<CustomerDashboardAdsBar> {
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
    if (!CustomerDashboardAdsBar.isSupported) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final service = context.read<AppState>().announcementService;

    return StreamBuilder<List<Announcement>>(
      stream: service.watchCustomerDashboardAnnouncements(),
      builder: (context, snapshot) {
        final slides = (snapshot.data ?? const []).take(5).toList();
        if (slides.isEmpty) {
          return _AdsCard(
            title: isAr ? 'تنبيهات الإدارة' : 'Management updates',
            body: isAr
                ? 'ستظهر هنا عروض وخصومات الإدارة.'
                : 'Discounts and notices from management appear here.',
          );
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
              height: 78,
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final item = slides[index];
                  return _AdsCard(title: item.title, body: item.body);
                },
              ),
            ),
            if (slides.length > 1) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slides.length; i++)
                    Container(
                      width: i == _page ? 14 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppBrandAssets.brandTeal
                            : AppBrandAssets.brandBorder,
                        borderRadius: BorderRadius.circular(99),
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

class _AdsCard extends StatelessWidget {
  const _AdsCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E8), Color(0xFFFFE8D6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.campaign_rounded,
            color: Color(0xFFC2410C),
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppBrandAssets.brandNavy,
                    fontSize: 14,
                  ),
                ),
                if (body.trim().isNotEmpty)
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppBrandAssets.brandMuted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
