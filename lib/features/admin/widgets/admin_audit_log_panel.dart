import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/admin_audit_service.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminAuditLogPanel extends StatefulWidget {
  const AdminAuditLogPanel({super.key});

  @override
  State<AdminAuditLogPanel> createState() => _AdminAuditLogPanelState();
}

class _AdminAuditLogPanelState extends State<AdminAuditLogPanel> {
  var _filters = AdminFilterCriteria.empty;

  bool _matches(AdminAuditLog log) {
    if (!_filters.matchesDate(log.createdAt)) return false;
    final q = _filters.query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack =
        '${log.adminName} ${log.action} ${log.entityType} ${log.entityId} ${log.details}'
            .toLowerCase();
    return haystack.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final service = context.read<AppState>().adminAuditService;
    final fmt = DateFormat.yMMMd(isAr ? 'ar' : 'en').add_jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminFilterBar(
          value: _filters,
          onChanged: (v) => setState(() => _filters = v),
          fields: const [
            AdminFilterField.dateRange,
            AdminFilterField.search,
          ],
          hintText: isAr ? 'بحث في السجل' : 'Search audit log',
        ),
        Expanded(
          child: StreamBuilder<List<AdminAuditLog>>(
            stream: service.watchRecent(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = (snapshot.data ?? const []).where(_matches).toList();

              if (items.isEmpty) {
                return Center(
                  child: Text(isAr ? 'لا توجد سجلات' : 'No audit entries'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final log = items[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(_iconForAction(log.action)),
                      ),
                      title: Text('${log.action} • ${log.entityType}'),
                      subtitle: Text(
                        [
                          log.adminName,
                          log.entityId,
                          if (log.details.isNotEmpty) log.details,
                          if (log.ipAddress != null && log.ipAddress!.isNotEmpty)
                            'IP: ${log.ipAddress}',
                          if (log.createdAt != null) fmt.format(log.createdAt!),
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

  IconData _iconForAction(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('block')) return Icons.block;
    if (lower.contains('delete') || lower.contains('remove')) {
      return Icons.delete_outline;
    }
    if (lower.contains('approve')) return Icons.check_circle_outline;
    if (lower.contains('wallet')) return Icons.account_balance_wallet_outlined;
    return Icons.history;
  }
}
