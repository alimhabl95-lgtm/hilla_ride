import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/admin_report_service.dart';
import 'package:hilla_ride/core/utils/web_download.dart';
import 'package:provider/provider.dart';

class AdminReportsPanel extends StatefulWidget {
  const AdminReportsPanel({super.key});

  @override
  State<AdminReportsPanel> createState() => _AdminReportsPanelState();
}

class _AdminReportsPanelState extends State<AdminReportsPanel> {
  var _period = AdminReportPeriod.monthly;
  var _reportType = AdminReportType.trips;
  DateTime? _customFrom;
  DateTime? _customTo;
  var _exporting = false;

  AdminReportRange get _range => AdminReportRange.forPeriod(
        _period,
        customFrom: _customFrom,
        customTo: _customTo,
      );

  String _reportTitle(bool isAr) {
    final typeLabel = switch (_reportType) {
      AdminReportType.trips => isAr ? 'الرحلات' : 'Trips',
      AdminReportType.deliveries => isAr ? 'التوصيل' : 'Deliveries',
      AdminReportType.drivers => isAr ? 'السائقون' : 'Drivers',
      AdminReportType.customers => isAr ? 'الزبائن' : 'Customers',
      AdminReportType.walletTransactions =>
        isAr ? 'معاملات المحفظة' : 'Wallet transactions',
      AdminReportType.businessRevenue =>
        isAr ? 'إيرادات الأعمال' : 'Business revenue',
      AdminReportType.platformRevenue =>
        isAr ? 'إيرادات المنصة' : 'Platform revenue',
    };
    return '$typeLabel — ${_range.start.toIso8601String().substring(0, 10)}';
  }

  Future<String> _buildCsv(AppState appState) async {
    final report = appState.adminReportService;
    final range = _range;

    switch (_reportType) {
      case AdminReportType.trips:
        final rides = await appState.adminService
            .watchRidesSince(range.start, limit: 2000)
            .first;
        return report.tripsCsv(rides, range);
      case AdminReportType.deliveries:
        final orders = await appState.businessService.watchAllOrders(limit: 2000).first;
        return report.deliveriesCsv(orders, range);
      case AdminReportType.drivers:
        final drivers = await appState.adminService.watchAllDrivers().first;
        return report.driversCsv(drivers);
      case AdminReportType.customers:
        final customers = await appState.adminService.watchCustomers().first;
        return report.customersCsv(customers);
      case AdminReportType.walletTransactions:
        final entries =
            await appState.walletService.watchRecentLedger(limit: 2000).first;
        return report.walletTransactionsCsv(entries, range);
      case AdminReportType.businessRevenue:
        final orders = await appState.businessService.watchAllOrders(limit: 2000).first;
        return report.businessRevenueCsv(orders, range);
      case AdminReportType.platformRevenue:
        final rides = await appState.adminService
            .watchCompletedRidesSince(range.start, limit: 2000)
            .first;
        return report.platformRevenueCsv(rides, range);
    }
  }

  Future<void> _exportCsv() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _exporting = true);
    try {
      final csv = await _buildCsv(context.read<AppState>());
      final filename =
          'hilla_${_reportType.name}_${_range.start.toIso8601String().substring(0, 10)}.csv';
      if (kIsWeb) {
        downloadTextFile(
          filename: filename,
          content: csv,
          mimeType: 'text/csv;charset=utf-8',
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr ? 'التصدير متاح على الويب فقط' : 'Export available on web only',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportHtml() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _exporting = true);
    try {
      final appState = context.read<AppState>();
      final csv = await _buildCsv(appState);
      final html = appState.adminReportService.printableHtml(
        title: _reportTitle(isAr),
        csvContent: csv,
        isAr: isAr,
      );
      final filename =
          'hilla_${_reportType.name}_${_range.start.toIso8601String().substring(0, 10)}.html';
      if (kIsWeb) {
        openPrintableHtml(filename: filename, htmlContent: html);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr ? 'التصدير متاح على الويب فقط' : 'Export available on web only',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAr ? 'التقارير' : 'Reports',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdminReportPeriod>(
                  value: _period,
                  decoration: InputDecoration(
                    labelText: isAr ? 'الفترة' : 'Period',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: AdminReportPeriod.daily,
                      child: Text(isAr ? 'يومي' : 'Daily'),
                    ),
                    DropdownMenuItem(
                      value: AdminReportPeriod.weekly,
                      child: Text(isAr ? 'أسبوعي' : 'Weekly'),
                    ),
                    DropdownMenuItem(
                      value: AdminReportPeriod.monthly,
                      child: Text(isAr ? 'شهري' : 'Monthly'),
                    ),
                    DropdownMenuItem(
                      value: AdminReportPeriod.custom,
                      child: Text(isAr ? 'مخصص' : 'Custom'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _period = v ?? _period),
                ),
                if (_period == AdminReportPeriod.custom) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _customFrom ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _customFrom = picked);
                            }
                          },
                          child: Text(
                            _customFrom == null
                                ? (isAr ? 'من' : 'From')
                                : _customFrom!.toIso8601String().substring(0, 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _customTo ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _customTo = picked);
                            }
                          },
                          child: Text(
                            _customTo == null
                                ? (isAr ? 'إلى' : 'To')
                                : _customTo!.toIso8601String().substring(0, 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<AdminReportType>(
                  value: _reportType,
                  decoration: InputDecoration(
                    labelText: isAr ? 'نوع التقرير' : 'Report type',
                    border: const OutlineInputBorder(),
                  ),
                  items: AdminReportType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(switch (t) {
                            AdminReportType.trips =>
                              isAr ? 'الرحلات' : 'Trips',
                            AdminReportType.deliveries =>
                              isAr ? 'التوصيل' : 'Deliveries',
                            AdminReportType.drivers =>
                              isAr ? 'السائقون' : 'Drivers',
                            AdminReportType.customers =>
                              isAr ? 'الزبائن' : 'Customers',
                            AdminReportType.walletTransactions =>
                              isAr ? 'معاملات المحفظة' : 'Wallet transactions',
                            AdminReportType.businessRevenue =>
                              isAr ? 'إيرادات الأعمال' : 'Business revenue',
                            AdminReportType.platformRevenue =>
                              isAr ? 'إيرادات المنصة' : 'Platform revenue',
                          }),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _reportType = v ?? _reportType),
                ),
                Text(
                  isAr
                      ? 'التصدير: Excel (CSV) للبيانات الخام، PDF (طباعة HTML) للتقارير المنسقة.'
                      : 'Export: Excel (CSV) for raw data, PDF (print HTML) for formatted reports.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _exporting ? null : _exportCsv,
                      icon: const Icon(Icons.download),
                      label: Text(
                        isAr ? 'تصدير Excel (CSV)' : 'Export Excel (CSV)',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exporting ? null : _exportHtml,
                      icon: const Icon(Icons.print),
                      label: Text(
                        isAr ? 'طباعة PDF (HTML)' : 'Print PDF (HTML)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isAr
                  ? 'النطاق: ${_range.start.toIso8601String().substring(0, 10)} — ${_range.end.toIso8601String().substring(0, 10)}'
                  : 'Range: ${_range.start.toIso8601String().substring(0, 10)} — ${_range.end.toIso8601String().substring(0, 10)}',
            ),
          ),
        ),
      ],
    );
  }
}
