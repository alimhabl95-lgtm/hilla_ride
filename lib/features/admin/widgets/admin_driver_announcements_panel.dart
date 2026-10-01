import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/announcement_icon.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminDriverAnnouncementsPanel extends StatefulWidget {
  const AdminDriverAnnouncementsPanel({super.key});

  @override
  State<AdminDriverAnnouncementsPanel> createState() =>
      _AdminDriverAnnouncementsPanelState();
}

class _AdminDriverAnnouncementsPanelState
    extends State<AdminDriverAnnouncementsPanel> {
  static const _iconOptions = [
    ('campaign', Icons.campaign_outlined),
    ('local_offer', Icons.local_offer_outlined),
    ('emoji_events', Icons.emoji_events_outlined),
    ('warning', Icons.warning_amber_outlined),
    ('build', Icons.build_outlined),
    ('info', Icons.info_outline),
    ('directions_car', Icons.directions_car_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final admin = context.read<AppState>().adminService;
    final fmt = DateFormat.yMMMd(isAr ? 'ar' : 'en').add_jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Text(
            isAr
                ? 'تظهر تلقائياً في لوحة السائق (Android) بدون تحديث التطبيق.'
                : 'Shows live on the Android driver dashboard — no app update needed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppBrandAssets.brandMuted,
                ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: () => _openEditor(context, isAr: isAr),
              icon: const Icon(Icons.add),
              label: Text(isAr ? 'إعلان جديد' : 'New announcement'),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Announcement>>(
            stream: admin.watchDriverDashboardAnnouncementsAdmin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    isAr ? 'لا توجد إعلانات بعد' : 'No driver announcements yet',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final live = item.isLiveAt(DateTime.now());
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppBrandAssets.brandTeal.withValues(alpha: 0.12),
                        child: Icon(
                          announcementIconData(item.iconKey),
                          color: AppBrandAssets.brandTealDark,
                        ),
                      ),
                      title: Text(item.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _scheduleLabel(item, fmt, isAr),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(
                              live
                                  ? (isAr ? 'نشط' : 'Active')
                                  : (isAr ? 'غير نشط' : 'Inactive'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: live
                                ? AppBrandAssets.brandSuccess
                                    .withValues(alpha: 0.15)
                                : AppBrandAssets.brandMuted
                                    .withValues(alpha: 0.15),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _openEditor(context, isAr: isAr, existing: item);
                              } else if (value == 'delete') {
                                await _confirmDelete(context, item, isAr);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(isAr ? 'تعديل' : 'Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(isAr ? 'حذف' : 'Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _scheduleLabel(Announcement item, DateFormat fmt, bool isAr) {
    final parts = <String>[];
    if (item.startsAt != null) {
      parts.add(
        isAr
            ? 'يبدأ: ${fmt.format(item.startsAt!)}'
            : 'Starts: ${fmt.format(item.startsAt!)}',
      );
    }
    if (item.expiresAt != null) {
      parts.add(
        isAr
            ? 'ينتهي: ${fmt.format(item.expiresAt!)}'
            : 'Ends: ${fmt.format(item.expiresAt!)}',
      );
    }
    if (parts.isEmpty) {
      return isAr ? 'بدون جدولة' : 'No schedule';
    }
    return parts.join(' · ');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Announcement item,
    bool isAr,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'حذف الإعلان؟' : 'Delete announcement?'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context
          .read<AppState>()
          .adminService
          .deleteDriverDashboardAnnouncement(item.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    required bool isAr,
    Announcement? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _AnnouncementEditorSheet(
        isAr: isAr,
        existing: existing,
        iconOptions: _iconOptions,
      ),
    );
  }
}

class _AnnouncementEditorSheet extends StatefulWidget {
  const _AnnouncementEditorSheet({
    required this.isAr,
    this.existing,
    required this.iconOptions,
  });

  final bool isAr;
  final Announcement? existing;
  final List<(String, IconData)> iconOptions;

  @override
  State<_AnnouncementEditorSheet> createState() =>
      _AnnouncementEditorSheetState();
}

class _AnnouncementEditorSheetState extends State<_AnnouncementEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _imageUrl;
  late bool _isActive;
  late String _iconKey;
  DateTime? _startsAt;
  DateTime? _expiresAt;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _imageUrl = TextEditingController(text: e?.imageUrl ?? '');
    _isActive = e?.isActive ?? true;
    _iconKey = e?.iconKey ?? 'campaign';
    _startsAt = e?.startsAt;
    _expiresAt = e?.expiresAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startsAt : _expiresAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _startsAt = combined;
      } else {
        _expiresAt = combined;
      }
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr ? 'العنوان والرسالة مطلوبان' : 'Title and message required',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final admin = context.read<AppState>().adminService;
      final imageUrl = _imageUrl.text.trim();
      if (widget.existing == null) {
        await admin.createDriverDashboardAnnouncement(
          title: title,
          body: body,
          isActive: _isActive,
          startsAt: _startsAt,
          expiresAt: _expiresAt,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
          iconKey: _iconKey,
        );
      } else {
        await admin.updateDriverDashboardAnnouncement(
          id: widget.existing!.id,
          title: title,
          body: body,
          isActive: _isActive,
          startsAt: _startsAt,
          expiresAt: _expiresAt,
          clearStartsAt: _startsAt == null,
          clearExpiresAt: _expiresAt == null,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
          iconKey: _iconKey,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final fmt = DateFormat.yMMMd(isAr ? 'ar' : 'en').add_jm();

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
              widget.existing == null
                  ? (isAr ? 'إعلان للسائقين' : 'Driver announcement')
                  : (isAr ? 'تعديل الإعلان' : 'Edit announcement'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: isAr ? 'العنوان' : 'Title',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isAr ? 'رسالة قصيرة' : 'Short message',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imageUrl,
              decoration: InputDecoration(
                labelText: isAr
                    ? 'رابط صورة (اختياري)'
                    : 'Image URL (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(isAr ? 'أيقونة' : 'Icon', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final option in widget.iconOptions)
                  ChoiceChip(
                    selected: _iconKey == option.$1,
                    onSelected: (_) => setState(() => _iconKey = option.$1),
                    label: Icon(option.$2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isAr ? 'نشط' : 'Active'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isAr ? 'تاريخ البداية' : 'Start date'),
              subtitle: Text(
                _startsAt == null ? (isAr ? 'غير محدد' : 'Not set') : fmt.format(_startsAt!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_startsAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _startsAt = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.event),
                    onPressed: () => _pickDate(start: true),
                  ),
                ],
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isAr ? 'تاريخ الانتهاء' : 'Expiry date'),
              subtitle: Text(
                _expiresAt == null ? (isAr ? 'غير محدد' : 'Not set') : fmt.format(_expiresAt!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_expiresAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _expiresAt = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.event),
                    onPressed: () => _pickDate(start: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isAr ? 'حفظ' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
