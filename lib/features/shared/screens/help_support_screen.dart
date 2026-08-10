import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/chat_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/features/shared/screens/support_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  SupportContactInfo? _contact;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    final contact =
        await context.read<AppState>().supportService.getContactInfo();
    if (mounted) setState(() => _contact = contact);
  }

  Future<void> _launchWhatsApp(String whatsapp) async {
    final digits = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<_FaqItem> _faqs(bool isAr) => [
        _FaqItem(
          question: isAr ? 'كيف أطلب رحلة؟' : 'How do I request a ride?',
          answer: isAr
              ? 'افتح الخريطة، اختر نقطة الانطلاق والوجهة، ثم اضغط "احجز رحلة".'
              : 'Open the map, pick pickup and destination, then tap Book ride.',
        ),
        _FaqItem(
          question: isAr ? 'كيف ألغي رحلة؟' : 'How do I cancel a ride?',
          answer: isAr
              ? 'يمكنك الإلغاء قبل بدء الرحلة من شاشة تتبع السائق.'
              : 'You can cancel before the trip starts from the track-driver screen.',
        ),
        _FaqItem(
          question: isAr ? 'كيف أدفع؟' : 'How do I pay?',
          answer: isAr
              ? 'الدفع نقداً للسائق بعد انتهاء الرحلة ما لم يُفعّل الدفع المسبق.'
              : 'Pay the driver in cash after the trip unless prepaid wallet is enabled.',
        ),
        _FaqItem(
          question: isAr ? 'كيف أبلّغ عن مشكلة؟' : 'How do I report a problem?',
          answer: isAr
              ? 'استخدم "الإبلاغ عن مشكلة" أدناه أو تواصل مع الدعم مباشرة.'
              : 'Use Report a problem below or contact support directly.',
        ),
        _FaqItem(
          question: isAr ? 'متى يتم الرد على الشكاوى؟' : 'When will complaints be answered?',
          answer: isAr
              ? 'يراجع فريق الإدارة الشكاوى خلال 24–48 ساعة.'
              : 'Management reviews complaints within 24–48 hours.',
        ),
      ];

  Future<void> _openReportSheet({
    required AppUser profile,
    required String category,
    required String subject,
    String targetRole = '',
    String targetLabel = '',
  }) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final targetController = TextEditingController();
    final bodyController = TextEditingController();
    final rideController = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subject,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (targetLabel.isNotEmpty)
                  TextField(
                    controller: targetController,
                    decoration: InputDecoration(
                      labelText: targetLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                if (targetLabel.isNotEmpty) const SizedBox(height: 12),
                TextField(
                  controller: rideController,
                  decoration: InputDecoration(
                    labelText: isAr
                        ? 'رقم الرحلة (اختياري)'
                        : 'Ride ID (optional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: isAr ? 'التفاصيل' : 'Details',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(isAr ? 'إرسال' : 'Submit'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (submitted != true || !mounted) {
      targetController.dispose();
      bodyController.dispose();
      rideController.dispose();
      return;
    }

    final body = bodyController.text.trim();
    if (body.isEmpty) {
      targetController.dispose();
      bodyController.dispose();
      rideController.dispose();
      return;
    }

    final targetInput = targetController.text.trim();
    final relatedRideId = rideController.text.trim();
    targetController.dispose();
    bodyController.dispose();
    rideController.dispose();

    final looksLikeUid = RegExp(r'^[A-Za-z0-9]{20,}$').hasMatch(targetInput);
    final targetUserId = looksLikeUid ? targetInput : '';
    final targetName = looksLikeUid ? '' : targetInput;

    try {
      final service = context.read<AppState>().complaintService;
      await service.createComplaint(
        userId: profile.uid,
        userRole: profile.role.value,
        userName: profile.name,
        subject: subject,
        body: body,
        category: category,
        relatedRideId: relatedRideId.isEmpty ? null : relatedRideId,
        targetName: targetName,
        targetRole: targetRole,
        targetUserId: targetUserId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم إرسال البلاغ' : 'Report submitted',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تعذر إرسال البلاغ' : 'Could not submit report',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final authService = context.read<AppState>().authService;
    final contact = _contact ?? SupportContactInfo.defaults;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'المساعدة والدعم' : 'Help & Support'),
      ),
      body: StreamBuilder<AppUser?>(
        stream: authService.watchCurrentProfile(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isAr ? 'الأسئلة الشائعة' : 'FAQ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._faqs(isAr).map(
                      (faq) => ExpansionTile(
                        title: Text(faq.question),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(faq.answer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isAr ? 'تواصل معنا' : 'Contact us',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    AppSecondaryButton(
                      label: isAr ? 'محادثة الدعم' : 'Contact support chat',
                      icon: Icons.chat_bubble_outline,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SupportScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    AppSecondaryButton(
                      label: l10n.whatsappSupport,
                      icon: Icons.chat,
                      onPressed: () => _launchWhatsApp(contact.whatsapp),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isAr ? 'الإبلاغ عن مشكلة' : 'Report a problem',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    AppSecondaryButton(
                      label: isAr ? 'بلّغ عن مشكلة عامة' : 'Report a problem',
                      icon: Icons.report_problem_outlined,
                      onPressed: () => _openReportSheet(
                        profile: profile,
                        category: 'general',
                        subject: isAr ? 'بلاغ عام' : 'General report',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (profile.role == UserRole.customer) ...[
                      AppSecondaryButton(
                        label: isAr ? 'بلّغ عن سائق' : 'Report a driver',
                        icon: Icons.local_taxi_outlined,
                        onPressed: () => _openReportSheet(
                          profile: profile,
                          category: 'driver',
                          subject: isAr ? 'بلاغ ضد سائق' : 'Report driver',
                          targetRole: 'driver',
                          targetLabel: isAr
                              ? 'اسم أو رقم السائق'
                              : 'Driver name or ID',
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppSecondaryButton(
                        label: isAr ? 'بلّغ عن متجر' : 'Report a business',
                        icon: Icons.store_outlined,
                        onPressed: () => _openReportSheet(
                          profile: profile,
                          category: 'business',
                          subject: isAr ? 'بلاغ ضد متجر' : 'Report business',
                          targetRole: 'businessOwner',
                          targetLabel:
                              isAr ? 'اسم المتجر' : 'Business name',
                        ),
                      ),
                    ],
                    if (profile.role == UserRole.driver) ...[
                      AppSecondaryButton(
                        label: isAr ? 'بلّغ عن راكب' : 'Report a customer',
                        icon: Icons.person_outline,
                        onPressed: () => _openReportSheet(
                          profile: profile,
                          category: 'customer',
                          subject:
                              isAr ? 'بلاغ ضد راكب' : 'Report customer',
                          targetRole: 'customer',
                          targetLabel: isAr
                              ? 'اسم أو رقم الراكب'
                              : 'Customer name or ID',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}
