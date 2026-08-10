import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/models/reward_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminRewardsPanel extends StatefulWidget {
  const AdminRewardsPanel({super.key});

  @override
  State<AdminRewardsPanel> createState() => _AdminRewardsPanelState();
}

class _AdminRewardsPanelState extends State<AdminRewardsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _selectedCampaignId;
  AdminFilterCriteria _filters = AdminFilterCriteria.empty;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final rewards = context.watch<AppState>().rewardService;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isAr ? 'مكافآت وحوافز السائقين' : 'Driver rewards & incentives',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openEditor(context, isAr: isAr),
                icon: const Icon(Icons.add),
                label: Text(isAr ? 'حملة جديدة' : 'New campaign'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            isAr
                ? 'أنشئ وعدّل الحملات من لوحة الإدارة — تُطبَّق فوراً بدون تحديث التطبيق. عند تحقيق الشروط تُضاف المكافأة تلقائياً إلى محفظة السائق.'
                : 'Create and edit campaigns here — they apply live with no app update. When conditions are met, rewards credit the driver wallet automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: isAr ? 'الحملات' : 'Campaigns'),
            Tab(text: isAr ? 'المنح' : 'Grants'),
            Tab(text: isAr ? 'سجل التدقيق' : 'Audit'),
          ],
        ),
        if (_tabs.index == 1 || _tabs.index == 2)
          AdminFilterBar(
            value: _filters,
            onChanged: (v) => setState(() => _filters = v),
            fields: const [
              AdminFilterField.dateRange,
              AdminFilterField.search,
            ],
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              StreamBuilder<List<RewardCampaign>>(
                stream: rewards.watchCampaigns(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('${snap.error}'));
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        isAr ? 'لا توجد حملات بعد' : 'No campaigns yet',
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final c = items[index];
                      final selected = _selectedCampaignId == c.id;
                      return Card(
                        color: selected
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.35)
                            : null,
                        child: ListTile(
                          onTap: () =>
                              setState(() => _selectedCampaignId = c.id),
                          title: Text(c.titleForLocale(isAr)),
                          subtitle: Text(
                            [
                              _statusLabel(c.status, isAr),
                              _rewardSummary(c.reward, isAr),
                              '${isAr ? 'منح' : 'Grants'}: ${c.totalGrantedCount}',
                              if (c.conditions.isNotEmpty)
                                '${c.conditions.length} ${isAr ? 'شروط' : 'conditions'}',
                            ].join(' • '),
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) => _onMenu(
                              context,
                              campaign: c,
                              action: value,
                              isAr: isAr,
                            ),
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(isAr ? 'تعديل' : 'Edit'),
                              ),
                              if (c.status != RewardCampaignStatus.active)
                                PopupMenuItem(
                                  value: 'activate',
                                  child: Text(isAr ? 'تفعيل' : 'Activate'),
                                ),
                              if (c.status == RewardCampaignStatus.active)
                                PopupMenuItem(
                                  value: 'pause',
                                  child: Text(isAr ? 'إيقاف مؤقت' : 'Pause'),
                                ),
                              if (c.status != RewardCampaignStatus.ended)
                                PopupMenuItem(
                                  value: 'end',
                                  child: Text(isAr ? 'إنهاء' : 'End'),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(isAr ? 'حذف' : 'Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              _GrantsTab(
                campaignId: _selectedCampaignId,
                isAr: isAr,
                filters: _filters,
              ),
              _AuditTab(
                campaignId: _selectedCampaignId,
                isAr: isAr,
                filters: _filters,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onMenu(
    BuildContext context, {
    required RewardCampaign campaign,
    required String action,
    required bool isAr,
  }) async {
    final rewards = context.read<AppState>().rewardService;
    try {
      switch (action) {
        case 'edit':
          await _openEditor(context, isAr: isAr, existing: campaign);
          break;
        case 'activate':
          await rewards.setCampaignStatus(
            id: campaign.id,
            status: RewardCampaignStatus.active,
          );
          break;
        case 'pause':
          await rewards.setCampaignStatus(
            id: campaign.id,
            status: RewardCampaignStatus.paused,
          );
          break;
        case 'end':
          await rewards.setCampaignStatus(
            id: campaign.id,
            status: RewardCampaignStatus.ended,
          );
          break;
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(isAr ? 'حذف الحملة؟' : 'Delete campaign?'),
              content: Text(
                isAr
                    ? 'سيتم إيقاف الحملة وحفظها كمحذوفة.'
                    : 'The campaign will be soft-deleted and stopped.',
              ),
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
          if (ok == true) await rewards.deleteCampaign(campaign.id);
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    required bool isAr,
    RewardCampaign? existing,
  }) async {
    final result = await showDialog<RewardCampaign>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CampaignEditorDialog(
        isAr: isAr,
        existing: existing,
      ),
    );
    if (result == null || !context.mounted) return;
    final rewards = context.read<AppState>().rewardService;
    try {
      final id = await rewards.saveCampaign(
        result,
        id: existing?.id,
      );
      if (!context.mounted) return;
      setState(() => _selectedCampaignId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'تم حفظ الحملة' : 'Campaign saved'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _GrantsTab extends StatelessWidget {
  const _GrantsTab({
    required this.campaignId,
    required this.isAr,
    required this.filters,
  });

  final String? campaignId;
  final bool isAr;
  final AdminFilterCriteria filters;

  @override
  Widget build(BuildContext context) {
    if (campaignId == null) {
      return Center(
        child: Text(
          isAr
              ? 'اختر حملة لعرض المنح'
              : 'Select a campaign to view grants',
        ),
      );
    }
    final rewards = context.watch<AppState>().rewardService;
    final fare = const FareService();
    return StreamBuilder<List<RewardGrant>>(
      stream: rewards.watchGrantsForCampaign(campaignId!),
      builder: (context, snap) {
        final items = (snap.data ?? const []).where((g) {
          if (!filters.matchesDate(g.createdAt)) return false;
          final q = filters.query.trim().toLowerCase();
          if (q.isEmpty) return true;
          final haystack =
              '${g.driverId} ${g.campaignTitleEn} ${g.campaignTitleAr} ${g.rewardType}'
                  .toLowerCase();
          return haystack.contains(q);
        }).toList();
        if (items.isEmpty) {
          return Center(
            child: Text(isAr ? 'لا منح لهذه الحملة بعد' : 'No grants yet'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final g = items[i];
            final when = g.createdAt == null
                ? ''
                : g.createdAt!.toLocal().toString().substring(0, 16);
            return ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: Text(g.titleForLocale(isAr)),
              subtitle: Text(
                [
                  g.driverId,
                  g.rewardType,
                  if (g.amountIqd > 0) fare.formatIqd(g.amountIqd),
                  when,
                ].where((e) => e.toString().isNotEmpty).join(' • '),
              ),
            );
          },
        );
      },
    );
  }
}

class _AuditTab extends StatelessWidget {
  const _AuditTab({
    required this.campaignId,
    required this.isAr,
    required this.filters,
  });

  final String? campaignId;
  final bool isAr;
  final AdminFilterCriteria filters;

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<AppState>().rewardService;
    return StreamBuilder<List<RewardAuditLog>>(
      stream: rewards.watchAuditLogs(campaignId: campaignId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final items = (snap.data ?? const []).where((log) {
          if (!filters.matchesDate(log.createdAt)) return false;
          final q = filters.query.trim().toLowerCase();
          if (q.isEmpty) return true;
          final haystack =
              '${log.action} ${log.campaignId} ${log.driverId} ${log.actorUid}'
                  .toLowerCase();
          return haystack.contains(q);
        }).toList();
        if (items.isEmpty) {
          return Center(
            child: Text(isAr ? 'لا سجلات بعد' : 'No audit logs yet'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final log = items[i];
            final when = log.createdAt == null
                ? ''
                : log.createdAt!.toLocal().toString().substring(0, 16);
            return ListTile(
              dense: true,
              leading: const Icon(Icons.history),
              title: Text(log.action),
              subtitle: Text(
                [
                  if (log.campaignId.isNotEmpty) log.campaignId,
                  if (log.driverId.isNotEmpty) log.driverId,
                  if (log.actorUid.isNotEmpty) log.actorUid,
                  when,
                ].join(' • '),
              ),
            );
          },
        );
      },
    );
  }
}

class _CampaignEditorDialog extends StatefulWidget {
  const _CampaignEditorDialog({
    required this.isAr,
    this.existing,
  });

  final bool isAr;
  final RewardCampaign? existing;

  @override
  State<_CampaignEditorDialog> createState() => _CampaignEditorDialogState();
}

class _CampaignEditorDialogState extends State<_CampaignEditorDialog> {
  late final TextEditingController _titleEn;
  late final TextEditingController _titleAr;
  late final TextEditingController _descEn;
  late final TextEditingController _descAr;
  late final TextEditingController _amount;
  late final TextEditingController _discount;
  late final TextEditingController _freeTrips;
  late final TextEditingController _durationDays;
  late final TextEditingController _maxPerDriver;
  late final TextEditingController _maxTotal;
  late final TextEditingController _cooldown;
  late final TextEditingController _priority;
  late final TextEditingController _customKey;
  late final TextEditingController _conditionValue;

  late RewardCampaignStatus _status;
  late RewardType _rewardType;
  late RewardConditionType _conditionType;
  late String _conditionOp;
  late String _conditionScope;
  late String _conditionLogic;
  late bool _notifyOnGrant;
  late List<RewardCondition> _conditions;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleEn = TextEditingController(text: e?.titleEn ?? '');
    _titleAr = TextEditingController(text: e?.titleAr ?? '');
    _descEn = TextEditingController(text: e?.descriptionEn ?? '');
    _descAr = TextEditingController(text: e?.descriptionAr ?? '');
    _amount = TextEditingController(
      text: (e?.reward.amountIqd ?? 5000).toString(),
    );
    _discount = TextEditingController(
      text: (e?.reward.commissionDiscountPercent ?? 50).toString(),
    );
    _freeTrips = TextEditingController(
      text: (e?.reward.freeTripsCount ?? 3).toString(),
    );
    _durationDays = TextEditingController(
      text: (e?.reward.durationDays ?? 0).toString(),
    );
    _maxPerDriver = TextEditingController(
      text: (e?.maxGrantsPerDriver ?? 1).toString(),
    );
    _maxTotal = TextEditingController(
      text: e?.maxTotalGrants?.toString() ?? '',
    );
    _cooldown = TextEditingController(
      text: (e?.cooldownHours ?? 0).toString(),
    );
    _priority = TextEditingController(text: (e?.priority ?? 0).toString());
    _customKey = TextEditingController();
    _conditionValue = TextEditingController(text: '10');
    _status = e?.status ?? RewardCampaignStatus.draft;
    _rewardType = e?.reward.type ?? RewardType.walletCredit;
    _conditionType = RewardConditionType.completedTrips;
    _conditionOp = 'gte';
    _conditionScope = 'campaign';
    _conditionLogic = e?.conditionLogic ?? 'and';
    _notifyOnGrant = e?.notifyOnGrant ?? true;
    _conditions = [...(e?.conditions ?? const [])];
    if (_conditions.isEmpty) {
      _conditions = [
        const RewardCondition(
          type: RewardConditionType.completedTrips,
          value: 10,
          scope: 'campaign',
        ),
      ];
    }
  }

  @override
  void dispose() {
    _titleEn.dispose();
    _titleAr.dispose();
    _descEn.dispose();
    _descAr.dispose();
    _amount.dispose();
    _discount.dispose();
    _freeTrips.dispose();
    _durationDays.dispose();
    _maxPerDriver.dispose();
    _maxTotal.dispose();
    _cooldown.dispose();
    _priority.dispose();
    _customKey.dispose();
    _conditionValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? (isAr ? 'حملة مكافآت جديدة' : 'New reward campaign')
            : (isAr ? 'تعديل الحملة' : 'Edit campaign'),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleEn,
                decoration: InputDecoration(
                  labelText: isAr ? 'العنوان (إنجليزي)' : 'Title (English)',
                ),
              ),
              TextField(
                controller: _titleAr,
                decoration: InputDecoration(
                  labelText: isAr ? 'العنوان (عربي)' : 'Title (Arabic)',
                ),
              ),
              TextField(
                controller: _descEn,
                decoration: InputDecoration(
                  labelText: isAr ? 'الوصف (إنجليزي)' : 'Description (EN)',
                ),
                maxLines: 2,
              ),
              TextField(
                controller: _descAr,
                decoration: InputDecoration(
                  labelText: isAr ? 'الوصف (عربي)' : 'Description (AR)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RewardCampaignStatus>(
                value: _status,
                decoration: InputDecoration(
                  labelText: isAr ? 'الحالة' : 'Status',
                ),
                items: RewardCampaignStatus.values
                    .where((s) => s != RewardCampaignStatus.deleted)
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(_statusLabel(s, isAr)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              DropdownButtonFormField<String>(
                value: _conditionLogic,
                decoration: InputDecoration(
                  labelText: isAr ? 'منطق الشروط' : 'Condition logic',
                ),
                items: [
                  DropdownMenuItem(
                    value: 'and',
                    child: Text(isAr ? 'كل الشروط (AND)' : 'All conditions (AND)'),
                  ),
                  DropdownMenuItem(
                    value: 'or',
                    child: Text(isAr ? 'أي شرط (OR)' : 'Any condition (OR)'),
                  ),
                ],
                onChanged: (v) => setState(() => _conditionLogic = v!),
              ),
              const SizedBox(height: 8),
              Text(
                isAr ? 'الشروط' : 'Conditions',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ..._conditions.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_conditionLabel(c, isAr)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _conditions.removeAt(i)),
                  ),
                );
              }),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<RewardConditionType>(
                      value: _conditionType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: isAr ? 'النوع' : 'Type',
                      ),
                      items: RewardConditionType.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(_conditionTypeLabel(t, isAr)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _conditionType = v!),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: DropdownButtonFormField<String>(
                      value: _conditionOp,
                      decoration: const InputDecoration(labelText: 'Op'),
                      items: const [
                        DropdownMenuItem(value: 'gte', child: Text('≥')),
                        DropdownMenuItem(value: 'gt', child: Text('>')),
                        DropdownMenuItem(value: 'lte', child: Text('≤')),
                        DropdownMenuItem(value: 'lt', child: Text('<')),
                        DropdownMenuItem(value: 'eq', child: Text('=')),
                      ],
                      onChanged: (v) => setState(() => _conditionOp = v!),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _conditionValue,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'القيمة' : 'Value',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      value: _conditionScope,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: isAr ? 'النطاق' : 'Scope',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'campaign',
                          child: Text(isAr ? 'خلال الحملة' : 'Campaign'),
                        ),
                        DropdownMenuItem(
                          value: 'lifetime',
                          child: Text(isAr ? 'مدى الحياة' : 'Lifetime'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text(isAr ? 'شهري' : 'Monthly'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _conditionScope = v!),
                    ),
                  ),
                  if (_conditionType == RewardConditionType.custom)
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _customKey,
                        decoration: InputDecoration(
                          labelText: isAr ? 'حقل مخصص' : 'Custom field',
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      final value = num.tryParse(_conditionValue.text.trim());
                      if (value == null) return;
                      setState(() {
                        _conditions.add(
                          RewardCondition(
                            type: _conditionType,
                            op: _conditionOp,
                            value: value,
                            scope: _conditionScope,
                            customKey: _customKey.text.trim(),
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text(isAr ? 'إضافة شرط' : 'Add condition'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isAr ? 'المكافأة' : 'Reward',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              DropdownButtonFormField<RewardType>(
                value: _rewardType,
                decoration: InputDecoration(
                  labelText: isAr ? 'نوع المكافأة' : 'Reward type',
                ),
                items: RewardType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(_rewardTypeLabel(t, isAr)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _rewardType = v!),
              ),
              if (_rewardType == RewardType.walletCredit ||
                  _rewardType == RewardType.bonus)
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr ? 'المبلغ (د.ع)' : 'Amount (IQD)',
                  ),
                ),
              if (_rewardType == RewardType.commissionDiscount)
                TextField(
                  controller: _discount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr
                        ? 'خصم العمولة (%)'
                        : 'Commission discount (%)',
                  ),
                ),
              if (_rewardType == RewardType.freeTrips)
                TextField(
                  controller: _freeTrips,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr ? 'رحلات مجانية (بدون عمولة)' : 'Free trips',
                  ),
                ),
              if (_rewardType == RewardType.commissionDiscount ||
                  _rewardType == RewardType.freeTrips)
                TextField(
                  controller: _durationDays,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr
                        ? 'المدة بالأيام (0 = بدون انتهاء)'
                        : 'Duration days (0 = no expiry)',
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                isAr ? 'الحدود' : 'Limits',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxPerDriver,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'لكل سائق' : 'Per driver',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxTotal,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'إجمالي المنح' : 'Max total grants',
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cooldown,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'تهدئة (ساعات)' : 'Cooldown (hours)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _priority,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'الأولوية' : 'Priority',
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isAr ? 'إشعار فوري عند المنح' : 'Push notify on grant',
                ),
                value: _notifyOnGrant,
                onChanged: (v) => setState(() => _notifyOnGrant = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isAr ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_conditions.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isAr
                        ? 'أضف شرطاً واحداً على الأقل'
                        : 'Add at least one condition',
                  ),
                ),
              );
              return;
            }
            final maxTotalText = _maxTotal.text.trim();
            final campaign = RewardCampaign(
              id: widget.existing?.id ?? '',
              titleEn: _titleEn.text.trim(),
              titleAr: _titleAr.text.trim(),
              descriptionEn: _descEn.text.trim(),
              descriptionAr: _descAr.text.trim(),
              status: _status,
              conditionLogic: _conditionLogic,
              conditions: _conditions,
              reward: RewardPayload(
                type: _rewardType,
                amountIqd: int.tryParse(_amount.text.trim()) ?? 0,
                commissionDiscountPercent:
                    double.tryParse(_discount.text.trim()) ?? 0,
                freeTripsCount: int.tryParse(_freeTrips.text.trim()) ?? 0,
                durationDays: int.tryParse(_durationDays.text.trim()) ?? 0,
              ),
              maxGrantsPerDriver: int.tryParse(_maxPerDriver.text.trim()) ?? 1,
              maxTotalGrants: maxTotalText.isEmpty
                  ? null
                  : int.tryParse(maxTotalText),
              cooldownHours: int.tryParse(_cooldown.text.trim()) ?? 0,
              priority: int.tryParse(_priority.text.trim()) ?? 0,
              notifyOnGrant: _notifyOnGrant,
              startAt: widget.existing?.startAt,
              endAt: widget.existing?.endAt,
            );
            Navigator.pop(context, campaign);
          },
          child: Text(isAr ? 'حفظ' : 'Save'),
        ),
      ],
    );
  }
}

String _statusLabel(RewardCampaignStatus status, bool isAr) {
  return switch (status) {
    RewardCampaignStatus.draft => isAr ? 'مسودة' : 'Draft',
    RewardCampaignStatus.active => isAr ? 'نشطة' : 'Active',
    RewardCampaignStatus.paused => isAr ? 'متوقفة' : 'Paused',
    RewardCampaignStatus.ended => isAr ? 'منتهية' : 'Ended',
    RewardCampaignStatus.deleted => isAr ? 'محذوفة' : 'Deleted',
  };
}

String _rewardTypeLabel(RewardType type, bool isAr) {
  return switch (type) {
    RewardType.walletCredit => isAr ? 'رصيد محفظة' : 'Wallet credit',
    RewardType.bonus => isAr ? 'مكافأة محفظة' : 'Wallet bonus',
    RewardType.commissionDiscount =>
      isAr ? 'خصم عمولة' : 'Commission discount',
    RewardType.freeTrips => isAr ? 'رحلات بدون عمولة' : 'Free trips',
    RewardType.custom => isAr ? 'مخصص (مستقبلي)' : 'Custom (future)',
  };
}

String _conditionTypeLabel(RewardConditionType type, bool isAr) {
  return switch (type) {
    RewardConditionType.completedTrips =>
      isAr ? 'رحلات مكتملة' : 'Completed trips',
    RewardConditionType.totalEarnings =>
      isAr ? 'إجمالي الأرباح' : 'Total earnings',
    RewardConditionType.onlineHours => isAr ? 'ساعات الاتصال' : 'Online hours',
    RewardConditionType.rating => isAr ? 'التقييم' : 'Rating',
    RewardConditionType.acceptanceRate =>
      isAr ? 'نسبة القبول' : 'Acceptance rate',
    RewardConditionType.cancellationRate =>
      isAr ? 'نسبة الإلغاء' : 'Cancellation rate',
    RewardConditionType.custom => isAr ? 'مخصص' : 'Custom',
  };
}

String _conditionLabel(RewardCondition c, bool isAr) {
  final type = _conditionTypeLabel(c.type, isAr);
  final custom = c.customKey.isNotEmpty ? ' (${c.customKey})' : '';
  return '$type$custom ${c.op} ${c.value} [${c.scope}]';
}

String _rewardSummary(RewardPayload reward, bool isAr) {
  return switch (reward.type) {
    RewardType.walletCredit || RewardType.bonus =>
      '${reward.amountIqd} IQD',
    RewardType.commissionDiscount =>
      '${reward.commissionDiscountPercent.toStringAsFixed(0)}% ${isAr ? 'خصم' : 'off'}',
    RewardType.freeTrips =>
      '${reward.freeTripsCount} ${isAr ? 'رحلات' : 'trips'}',
    RewardType.custom => isAr ? 'مخصص' : 'Custom',
  };
}
