import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:intl/intl.dart';

enum AdminReportType {
  trips,
  deliveries,
  drivers,
  customers,
  walletTransactions,
  businessRevenue,
  platformRevenue,
}

enum AdminReportPeriod {
  daily,
  weekly,
  monthly,
  custom,
}

class AdminReportRange {
  const AdminReportRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  static AdminReportRange forPeriod(
    AdminReportPeriod period, {
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (period) {
      case AdminReportPeriod.daily:
        final start = DateTime(now.year, now.month, now.day);
        return AdminReportRange(start: start, end: todayEnd);
      case AdminReportPeriod.weekly:
        final start = todayEnd.subtract(const Duration(days: 6));
        return AdminReportRange(
          start: DateTime(start.year, start.month, start.day),
          end: todayEnd,
        );
      case AdminReportPeriod.monthly:
        final start = DateTime(now.year, now.month, 1);
        return AdminReportRange(start: start, end: todayEnd);
      case AdminReportPeriod.custom:
        final from = customFrom ?? DateTime(now.year, now.month, 1);
        final to = customTo ?? todayEnd;
        return AdminReportRange(
          start: DateTime(from.year, from.month, from.day),
          end: DateTime(to.year, to.month, to.day, 23, 59, 59),
        );
    }
  }
}

class AdminReportService {
  String escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  bool _inRange(DateTime? value, AdminReportRange range) {
    if (value == null) return false;
    return !value.isBefore(range.start) && !value.isAfter(range.end);
  }

  String tripsCsv(List<Ride> rides, AdminReportRange range) {
    final filtered = rides.where((r) => _inRange(r.createdAt, range)).toList();
    final header = [
      'Ride ID',
      'Ride Number',
      'Status',
      'Customer ID',
      'Driver ID',
      'Pickup',
      'Destination',
      'Fare IQD',
      'Platform Commission IQD',
      'District',
      'Sub District',
      'Created At',
      'Completed At',
    ];
    final rows = filtered.map((r) {
      return [
        r.id,
        r.rideNumber,
        r.status.name,
        r.customerId,
        r.driverId ?? '',
        r.pickupLabel,
        r.destinationLabel,
        '${r.fareAmountIqd}',
        '${r.platformCommissionIqd}',
        r.districtId,
        r.subDistrictId,
        _fmtDate(r.createdAt),
        _fmtDate(r.completedAt),
      ].map(escapeCsv).join(',');
    });
    return '${header.map(escapeCsv).join(',')}\n${rows.join('\n')}';
  }

  String deliveriesCsv(List<BusinessOrder> orders, AdminReportRange range) {
    final filtered =
        orders.where((o) => _inRange(o.createdAt, range)).toList();
    final header = [
      'Order ID',
      'Business ID',
      'Customer ID',
      'Driver ID',
      'Status',
      'Total IQD',
      'Delivery Fee IQD',
      'District',
      'Created At',
      'Delivered At',
    ];
    final rows = filtered.map((o) {
      return [
        o.id,
        o.businessId,
        o.customerId,
        o.driverId,
        o.status.name,
        '${o.totalIqd}',
        '${o.deliveryFeeIqd}',
        o.districtId,
        _fmtDate(o.createdAt),
        _fmtDate(o.updatedAt),
      ].map(escapeCsv).join(',');
    });
    return '${header.map(escapeCsv).join(',')}\n${rows.join('\n')}';
  }

  String driversCsv(List<DriverProfile> drivers) {
    final header = [
      'Driver ID',
      'Name',
      'Phone',
      'Status',
      'Completed Rides',
      'Cancelled Rides',
      'Rating',
      'Wallet Balance IQD',
      'District',
      'Sub District',
      'Offers Received',
      'Offers Accepted',
      'Online Hours',
      'Rewards Earned IQD',
    ];
    final rows = drivers.map((d) {
      final onlineHours = (d.onlineSecondsTotal / 3600).toStringAsFixed(1);
      return [
        d.uid,
        d.name,
        d.phone,
        d.approvalStatus.name,
        '${d.completedRidesCount}',
        '${d.cancelledRidesCount}',
        d.rating.toStringAsFixed(2),
        '${d.walletBalanceIqd}',
        d.assignedDistrictId,
        d.assignedSubDistrictId,
        '${d.statsOffersReceived}',
        '${d.statsOffersAccepted}',
        onlineHours,
        '${d.totalRewardsEarnedIqd}',
      ].map(escapeCsv).join(',');
    });
    return '${header.map(escapeCsv).join(',')}\n${rows.join('\n')}';
  }

  String customersCsv(List<AppUser> customers) {
    final header = [
      'User ID',
      'Name',
      'Phone',
      'Blocked',
      'Cancelled Rides',
      'Created At',
    ];
    final rows = customers.map((c) {
      return [
        c.uid,
        c.name,
        c.phone,
        c.isBlocked ? 'yes' : 'no',
        '${c.cancelledRidesCount}',
        _fmtDate(c.createdAt),
      ].map(escapeCsv).join(',');
    });
    return '${header.map(escapeCsv).join(',')}\n${rows.join('\n')}';
  }

  String walletTransactionsCsv(
    List<WalletLedgerEntry> entries,
    AdminReportRange range,
  ) {
    final filtered =
        entries.where((e) => _inRange(e.createdAt, range)).toList();
    final header = [
      'Entry ID',
      'Driver ID',
      'Type',
      'Amount IQD',
      'Balance After IQD',
      'Note',
      'Created At',
    ];
    final rows = filtered.map((e) {
      return [
        e.id,
        e.driverId,
        e.type.name,
        '${e.amountIqd}',
        '${e.balanceAfterIqd}',
        e.note,
        _fmtDate(e.createdAt),
      ].map(escapeCsv).join(',');
    });
    return '${header.map(escapeCsv).join(',')}\n${rows.join('\n')}';
  }

  String businessRevenueCsv(
    List<BusinessOrder> orders,
    AdminReportRange range,
  ) {
    final delivered = orders.where((o) {
      if (o.status != BusinessOrderStatus.delivered) return false;
      return _inRange(o.updatedAt ?? o.createdAt, range);
    }).toList();
    final header = [
      'Order ID',
      'Business ID',
      'Total IQD',
      'Delivery Fee IQD',
      'Delivered At',
    ];
    final rows = delivered.map((o) {
      return [
        o.id,
        o.businessId,
        '${o.totalIqd}',
        '${o.deliveryFeeIqd}',
        _fmtDate(o.updatedAt ?? o.createdAt),
      ].map(escapeCsv).join(',');
    });
    return '${header.map(escapeCsv).join(',')}\n${rows.join('\n')}';
  }

  String platformRevenueCsv(List<Ride> rides, AdminReportRange range) {
    final completed = rides.where((r) {
      if (r.status != RideStatus.completed) return false;
      return _inRange(r.completedAt ?? r.createdAt, range);
    }).toList();
    final header = [
      'Ride ID',
      'Ride Number',
      'Fare IQD',
      'Platform Commission IQD',
      'Driver Earnings IQD',
      'Completed At',
    ];
    final rows = completed.map((r) {
      return [
        r.id,
        r.rideNumber,
        '${r.fareAmountIqd}',
        '${r.platformCommissionIqd}',
        '${r.driverEarningsIqd}',
        _fmtDate(r.completedAt),
      ].map(escapeCsv).join(',');
    });
    return '${header.map(escapeCsv).join(',')}\n${rows.join('\n')}';
  }

  String printableHtml({
    required String title,
    required String csvContent,
    required bool isAr,
  }) {
    final lines = csvContent.split('\n');
    final tableRows = lines.map((line) {
      final cells = _parseCsvLine(line);
      return '<tr>${cells.map((c) => '<td>${_htmlEscape(c)}</td>').join()}</tr>';
    }).join('\n');

    return '''
<!DOCTYPE html>
<html lang="${isAr ? 'ar' : 'en'}" dir="${isAr ? 'rtl' : 'ltr'}">
<head>
  <meta charset="utf-8">
  <title>${_htmlEscape(title)}</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; }
    h1 { font-size: 20px; margin-bottom: 16px; }
    table { border-collapse: collapse; width: 100%; font-size: 12px; }
    th, td { border: 1px solid #ccc; padding: 6px 8px; text-align: start; }
    th { background: #f5f5f5; }
    @media print { body { margin: 12px; } }
  </style>
</head>
<body>
  <h1>${_htmlEscape(title)}</h1>
  <table>
    $tableRows
  </table>
  <script>window.onload = function() { window.print(); };</script>
</body>
</html>
''';
  }

  String _htmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString());
    return result;
  }
}
