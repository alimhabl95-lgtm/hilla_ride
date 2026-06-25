import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/shared/widgets/ride_earnings_summary.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({
    super.key,
    this.customerId,
    this.driverId,
    required this.title,
    this.statusFilter,
  }) : assert(customerId != null || driverId != null);

  final String? customerId;
  final String? driverId;
  final String title;
  final RideStatus? statusFilter;

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  String? _monthFilterKey;

  DateTime? _rideWhen(Ride ride) => ride.completedAt ?? ride.createdAt;

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _monthLabel(String monthKey, String localeName) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return monthKey;
    return DateFormat.yMMMM(localeName).format(DateTime(year, month));
  }

  List<String> _monthKeysFromRides(List<Ride> rides) {
    final keys = <String>{};
    for (final ride in rides) {
      final when = _rideWhen(ride);
      if (when != null) keys.add(_monthKey(when));
    }
    final sorted = keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  List<Ride> _filterByMonth(List<Ride> rides) {
    if (_monthFilterKey == null) return rides;
    return rides.where((ride) {
      final when = _rideWhen(ride);
      return when != null && _monthKey(when) == _monthFilterKey;
    }).toList();
  }

  Map<String, List<Ride>> _groupByMonth(List<Ride> rides) {
    final grouped = <String, List<Ride>>{};
    for (final ride in rides) {
      final when = _rideWhen(ride);
      if (when == null) continue;
      final key = _monthKey(when);
      grouped.putIfAbsent(key, () => []).add(ride);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final aWhen = _rideWhen(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bWhen = _rideWhen(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bWhen.compareTo(aWhen);
      });
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;
    const fareService = FareService();
    final stream = widget.customerId != null
        ? rideService.watchRideHistoryForCustomer(
            widget.customerId!,
            statusFilter: widget.statusFilter,
          )
        : rideService.watchRideHistoryForDriver(
            widget.driverId!,
            statusFilter: widget.statusFilter,
          );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<List<Ride>>(
        stream: stream,
        builder: (context, snapshot) {
          final allRides = snapshot.data ?? const [];
          final monthKeys = _monthKeysFromRides(allRides);
          final rides = _filterByMonth(allRides);
          final completedCount = widget.statusFilter == RideStatus.completed
              ? rides.length
              : rides.where((r) => r.status == RideStatus.completed).length;

          if (allRides.isEmpty) {
            return Center(child: Text(l10n.noRideHistory));
          }

          final grouped = _groupByMonth(rides);
          final visibleMonthKeys = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String?>(
                value: _monthFilterKey,
                decoration: InputDecoration(
                  labelText: l10n.filterByMonth,
                  prefixIcon: const Icon(Icons.calendar_month_outlined),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.allMonths),
                  ),
                  for (final key in monthKeys)
                    DropdownMenuItem<String?>(
                      value: key,
                      child: Text(_monthLabel(key, l10n.localeName)),
                    ),
                ],
                onChanged: (value) => setState(() => _monthFilterKey = value),
              ),
              const SizedBox(height: 16),
              if (rides.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(l10n.noRideHistory),
                  ),
                )
              else ...[
                if (widget.statusFilter == null ||
                    widget.statusFilter == RideStatus.completed)
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.totalTripsCount(completedCount),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.tripHistoryHint,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.statusFilter == null ||
                    widget.statusFilter == RideStatus.completed)
                  const SizedBox(height: 16),
                for (final monthKey in visibleMonthKeys) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _monthLabel(monthKey, l10n.localeName),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          l10n.tripsInMonth(grouped[monthKey]!.length),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  ...grouped[monthKey]!.map((ride) {
                    final when = _rideWhen(ride);
                    final dateLabel = when == null
                        ? '—'
                        : DateFormat.yMMMd(l10n.localeName)
                            .add_jm()
                            .format(when);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: Icon(
                            ride.status == RideStatus.completed
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            color: ride.status == RideStatus.completed
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            '${ride.pickupLabel} → ${ride.destinationLabel}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${l10n.tripDateTime}: $dateLabel'),
                              Text(
                                '${l10n.statusLabel}: ${ride.status.name} • ${fareService.formatIqd(ride.fareAmountIqd, locale: l10n.localeName)}',
                              ),
                              if (widget.driverId != null &&
                                  ride.status == RideStatus.completed)
                                RideEarningsSummary(
                                  ride: ride,
                                  showDriverNet: true,
                                ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
