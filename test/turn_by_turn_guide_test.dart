import 'package:flutter_test/flutter_test.dart';
import 'package:hilla_ride/core/services/turn_by_turn_guide.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('shows the upcoming turn distance and advances after the maneuver', () {
    final steps = [
      NavigationStep(
        instruction: 'Head north',
        maneuver: 'straight',
        distanceMeters: 40,
        durationSeconds: 8,
        start: const LatLng(32.4800, 44.4300),
        end: const LatLng(32.4804, 44.4300),
      ),
      NavigationStep(
        instruction: 'Turn right',
        maneuver: 'turn-right',
        distanceMeters: 200,
        durationSeconds: 40,
        start: const LatLng(32.4804, 44.4300),
        end: const LatLng(32.4804, 44.4322),
      ),
    ];

    final beforeTurn = TurnByTurnGuide.evaluate(
      steps: steps,
      polyline: [steps.first.start, steps.first.end, steps.last.end],
      driver: const LatLng(32.48035, 44.4300),
      isEstimated: false,
    );
    expect(beforeTurn, isNotNull);
    expect(beforeTurn!.instruction, 'Turn right');
    expect(beforeTurn.metersToManeuver, greaterThan(100));
    expect(beforeTurn.offRoute, isFalse);

    final onRoute = TurnByTurnGuide.evaluate(
      steps: steps,
      polyline: [steps.first.start, steps.first.end, steps.last.end],
      driver: const LatLng(32.4801, 44.4300),
      isEstimated: false,
    );
    expect(onRoute!.instruction, 'Head north');
    expect(onRoute.metersToManeuver, lessThan(80));
  });

  test('marks the driver off route when they leave the road', () {
    const line = [
      LatLng(32.4800, 44.4300),
      LatLng(32.4810, 44.4300),
      LatLng(32.4820, 44.4300),
      LatLng(32.4830, 44.4300),
      LatLng(32.4840, 44.4300),
      LatLng(32.4850, 44.4300),
    ];
    final cue = TurnByTurnGuide.evaluate(
      steps: [
        NavigationStep(
          instruction: 'Continue',
          maneuver: 'straight',
          distanceMeters: 500,
          durationSeconds: 60,
          start: line.first,
          end: line.last,
        ),
      ],
      polyline: line,
      driver: const LatLng(32.4820, 44.4320),
      isEstimated: false,
    );
    expect(cue!.offRoute, isTrue);
    expect(cue.metersOffRoute, greaterThan(55));
  });

  test('strips html from direction instructions', () {
    expect(
      TurnByTurnGuide.stripHtml('Turn <b>right</b> onto Main'),
      'Turn right onto Main',
    );
  });
}
