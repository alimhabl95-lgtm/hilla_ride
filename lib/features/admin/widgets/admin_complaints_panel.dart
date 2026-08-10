import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/models/complaint_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminComplaintsPanel extends StatefulWidget {
  const AdminComplaintsPanel({super.key});

  @override
  State<AdminComplaintsPanel> createState() => _AdminComplaintsPanelState();
}

class _AdminComplaintsPanelState extends State<AdminComplaintsPanel> {
  var _filters = AdminFilterCriteria.empty;

  bool _matches(Complaint c) {
    if (!_filters.matchesGeo(
      provinceId: c.provinceId,
      districtId: c.districtId,
      subDistrictId: c.subDistrictId,
    )) {
      return false;
    }
    if (!_filters.matchesDate(c.createdAt)) return false;
    final q = _filters.query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack =
        '${c.userName} ${c.subject} ${c.body} ${c.userRole} ${c.id} '
                '${c.targetName} ${c.targetRole} ${c.targetUserId} ${c.category}'
            .toLowerCase();
    return haystack.contains(q);
  }

  Color _statusColor(ComplaintStatus status) {
    return switch (status) {
      ComplaintStatus.open => Colors.orange,
      ComplaintStatus.inProgress => Colors.blue,
      ComplaintStatus.resolved => Colors.green,
      ComplaintStatus.closed => Colors.grey,
    };
  }

  Future<void> _showReplyDialog(Complaint complaint) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final controller = TextEditingController(text: complaint.adminReply);
    final service = context.read<AppState>().complaintService;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAr ? 'رد على الشكوى' : 'Reply to complaint'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                complaint.subject,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(complaint.body),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: isAr ? 'رد الإدارة' : 'Admin reply',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'reply'),
            child: Text(isAr ? 'إرسال الرد' : 'Send reply'),
          ),
          if (complaint.status != ComplaintStatus.resolved)
            TextButton(
              onPressed: () => Navigator.pop(context, 'resolve'),
              child: Text(isAr ? 'حل وإرسال' : 'Resolve & send'),
            ),
        ],
      ),
    );

    if (action == null || !mounted) return;
    final reply = controller.text.trim();
    if (reply.isEmpty) return;

    await service.reply(
      complaintId: complaint.id,
      adminReply: reply,
      status: action == 'resolve'
          ? ComplaintStatus.resolved
          : ComplaintStatus.inProgress,
    );
    controller.dispose();
  }

  Future<void> _banUser(Complaint complaint) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAr ? 'حظر المستخدم' : 'Ban user'),
        content: Text(
          isAr
              ? 'حظر ${complaint.userName}؟'
              : 'Ban ${complaint.userName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isAr ? 'حظر' : 'Ban'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final appState = context.read<AppState>();
    await appState.complaintService.banUser(
      adminService: appState.adminService,
      driverService: appState.driverService,
      userId: complaint.userId,
      userRole: complaint.userRole,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final catalog = ServiceAreaCatalog.instance;
    final service = context.read<AppState>().complaintService;
    final fmt = DateFormat.yMMMd(isAr ? 'ar' : 'en').add_jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminFilterBar(
          value: _filters,
          onChanged: (v) => setState(() => _filters = v),
          hintText: isAr ? 'بحث في الشكاوى' : 'Search complaints',
        ),
        Expanded(
          child: StreamBuilder<List<Complaint>>(
            stream: service.watchAll(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = (snapshot.data ?? const [])
                  .where(_matches)
                  .toList();

              if (items.isEmpty) {
                return Center(
                  child: Text(isAr ? 'لا توجد شكاوى' : 'No complaints'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final c = items[index];
                  final geo = [
                    if (c.provinceId.isNotEmpty)
                      catalog.localizedProvinceName(
                        c.provinceId,
                        isAr: isAr,
                      ),
                    if (c.districtId.isNotEmpty)
                      catalog.localizedDistrictName(
                        c.districtId,
                        isAr: isAr,
                      ),
                    if (c.subDistrictId.isNotEmpty)
                      catalog.localizedSubName(c.subDistrictId, isAr: isAr),
                  ].join(' • ');

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.subject,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              if (c.category.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Chip(
                                    label: Text(c.category),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              Chip(
                                label: Text(c.status.name),
                                backgroundColor:
                                    _statusColor(c.status).withValues(alpha: 0.15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${c.userName} (${c.userRole}) • ${c.createdAt == null ? '' : fmt.format(c.createdAt!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (c.hasTarget) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isAr
                                        ? 'ضد: ${c.targetName.isNotEmpty ? c.targetName : c.targetUserId} (${c.targetRole})'
                                        : 'Against: ${c.targetName.isNotEmpty ? c.targetName : c.targetUserId} (${c.targetRole})',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                if (c.targetUserId.isNotEmpty)
                                  _TargetFlaggedBadge(
                                    targetUserId: c.targetUserId,
                                    targetRole: c.targetRole,
                                    isAr: isAr,
                                  ),
                              ],
                            ),
                          ],
                          if (geo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(geo,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                          const SizedBox(height: 8),
                          Text(c.body),
                          if (c.adminReply.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              isAr ? 'رد الإدارة:' : 'Admin reply:',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(c.adminReply),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showReplyDialog(c),
                                icon: const Icon(Icons.reply, size: 18),
                                label: Text(isAr ? 'رد' : 'Reply'),
                              ),
                              if (c.status != ComplaintStatus.resolved &&
                                  c.status != ComplaintStatus.closed)
                                OutlinedButton.icon(
                                  onPressed: () => service.updateStatus(
                                    complaintId: c.id,
                                    status: ComplaintStatus.resolved,
                                  ),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: Text(isAr ? 'حل' : 'Resolve'),
                                ),
                              if (c.status != ComplaintStatus.closed)
                                OutlinedButton.icon(
                                  onPressed: () => service.close(
                                    complaintId: c.id,
                                  ),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: Text(isAr ? 'إغلاق' : 'Close'),
                                ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () => _banUser(c),
                                icon: const Icon(Icons.block, size: 18),
                                label: Text(isAr ? 'حظر' : 'Ban user'),
                              ),
                            ],
                          ),
                        ],
                      ),
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

class _TargetFlaggedBadge extends StatelessWidget {
  const _TargetFlaggedBadge({
    required this.targetUserId,
    required this.targetRole,
    required this.isAr,
  });

  final String targetUserId;
  final String targetRole;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final collection =
        targetRole.toLowerCase() == 'driver' ? 'drivers' : 'users';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .doc(targetUserId)
          .snapshots(),
      builder: (context, snapshot) {
        final flagged = snapshot.data?.data()?['reviewFlagged'] == true;
        if (!flagged) return const SizedBox.shrink();
        return Chip(
          label: Text(isAr ? 'مُعلّم للمراجعة' : 'Flagged'),
          backgroundColor: Colors.red.withValues(alpha: 0.12),
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.error),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}
