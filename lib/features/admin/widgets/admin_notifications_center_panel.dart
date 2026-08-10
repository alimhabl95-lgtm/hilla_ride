import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/broadcast_service.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminNotificationsCenterPanel extends StatefulWidget {
  const AdminNotificationsCenterPanel({super.key});

  @override
  State<AdminNotificationsCenterPanel> createState() =>
      _AdminNotificationsCenterPanelState();
}

class _AdminNotificationsCenterPanelState
    extends State<AdminNotificationsCenterPanel> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _userIdController = TextEditingController();
  var _audience = 'allDrivers';
  var _geoFilters = AdminFilterCriteria.empty;
  var _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  bool get _needsGeo =>
      _audience == 'province' ||
      _audience == 'district' ||
      _audience == 'subDistrict';

  bool get _needsUserId => _audience == 'individual';

  Future<void> _send() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'العنوان والرسالة مطلوبان' : 'Title and message required'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final broadcast = context.read<AppState>().broadcastService;
      final result = await broadcast.sendAnnouncement(
        audience: _audience,
        title: title,
        message: message,
        provinceId: _geoFilters.provinceId,
        districtId: _geoFilters.districtId,
        subDistrictId: _geoFilters.subDistrictId,
        targetUserId: _needsUserId ? _userIdController.text.trim() : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'تم الإرسال إلى ${result.sent} من ${result.total}'
                : 'Sent to ${result.sent} of ${result.total}',
          ),
        ),
      );
      _messageController.clear();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '$e')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final broadcast = context.read<AppState>().broadcastService;
    final fmt = DateFormat.yMMMd(isAr ? 'ar' : 'en').add_jm();
    final catalog = ServiceAreaCatalog.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAr ? 'إرسال إشعار' : 'Send notification',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _audience,
                  decoration: InputDecoration(
                    labelText: isAr ? 'الجمهور' : 'Audience',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'allDrivers',
                      child: Text(isAr ? 'كل السائقين' : 'All drivers'),
                    ),
                    DropdownMenuItem(
                      value: 'allCustomers',
                      child: Text(isAr ? 'كل الزبائن' : 'All customers'),
                    ),
                    DropdownMenuItem(
                      value: 'businesses',
                      child: Text(isAr ? 'شركاء الأعمال' : 'Businesses'),
                    ),
                    DropdownMenuItem(
                      value: 'province',
                      child: Text(isAr ? 'محافظة' : 'Province'),
                    ),
                    DropdownMenuItem(
                      value: 'district',
                      child: Text(isAr ? 'قضاء' : 'District'),
                    ),
                    DropdownMenuItem(
                      value: 'subDistrict',
                      child: Text(isAr ? 'ناحية' : 'Sub-district'),
                    ),
                    DropdownMenuItem(
                      value: 'individual',
                      child: Text(isAr ? 'مستخدم محدد' : 'Individual user'),
                    ),
                  ],
                  onChanged: _sending
                      ? null
                      : (v) => setState(() => _audience = v ?? 'allDrivers'),
                ),
                if (_needsGeo) ...[
                  const SizedBox(height: 12),
                  AdminFilterBar(
                    value: _geoFilters,
                    onChanged: (v) => setState(() => _geoFilters = v),
                    fields: switch (_audience) {
                      'province' => const [AdminFilterField.province],
                      'district' => const [
                          AdminFilterField.province,
                          AdminFilterField.district,
                        ],
                      'subDistrict' => const [
                          AdminFilterField.province,
                          AdminFilterField.district,
                          AdminFilterField.subDistrict,
                        ],
                      _ => const [],
                    },
                  ),
                ],
                if (_needsUserId) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userIdController,
                    decoration: InputDecoration(
                      labelText: isAr ? 'معرف المستخدم' : 'User ID',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: isAr ? 'العنوان' : 'Title',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: isAr ? 'الرسالة' : 'Message',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(isAr ? 'إرسال' : 'Send'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            isAr ? 'الإعلانات الأخيرة' : 'Recent announcements',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AnnouncementRecord>>(
            stream: broadcast.watchRecentAnnouncements(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return Center(
                  child: Text(isAr ? 'لا توجد إعلانات' : 'No announcements'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final a = items[index];
                  final targeting = [
                    if (a.provinceId != null && a.provinceId!.isNotEmpty)
                      catalog.localizedProvinceName(
                        a.provinceId!,
                        isAr: isAr,
                      ),
                    if (a.districtId != null && a.districtId!.isNotEmpty)
                      catalog.localizedDistrictName(
                        a.districtId!,
                        isAr: isAr,
                      ),
                    if (a.subDistrictId != null && a.subDistrictId!.isNotEmpty)
                      catalog.localizedSubName(a.subDistrictId!, isAr: isAr),
                    if (a.targetUserId != null && a.targetUserId!.isNotEmpty)
                      a.targetUserId!,
                  ].join(' • ');

                  return Card(
                    child: ListTile(
                      title: Text(a.title),
                      subtitle: Text(
                        [
                          a.audience,
                          if (targeting.isNotEmpty) targeting,
                          a.body,
                          if (a.createdAt != null) fmt.format(a.createdAt!),
                          '${a.sentCount} ${isAr ? 'مستلم' : 'recipients'}',
                        ].join('\n'),
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
}
