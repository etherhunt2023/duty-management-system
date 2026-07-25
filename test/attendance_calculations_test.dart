import 'package:flutter_test/flutter_test.dart';
import '../lib/src/core/utils/duty_calculator.dart';

void main() {
  group('Duty Calculator Tests', () {
    test('Time string parsing to minutes', () {
      expect(DutyCalculator.timeStringToMinutes('08:40'), equals(520));
      expect(DutyCalculator.timeStringToMinutes('16:00'), equals(960));
      expect(DutyCalculator.timeStringToMinutes('00:00'), equals(0));
      expect(DutyCalculator.timeStringToMinutes('17:00'), equals(1020));
    });

    test('Minutes to time string formatting', () {
      expect(DutyCalculator.minutesToTimeString(520), equals('08:40'));
      expect(DutyCalculator.minutesToTimeString(960), equals('16:00'));
      expect(DutyCalculator.minutesToTimeString(0), equals('00:00'));
      expect(DutyCalculator.minutesToTimeString(100), equals('01:40'));
    });

    test('Calculate Duty Minutes for Shift A (Morning)', () {
      // Shift A: 08:40 to 17:00 (Total 8h 20m = 500m)
      final duty = DutyCalculator.calculateDutyMinutes('08:40', '17:00');
      expect(duty, equals(500));
      
      final ot = DutyCalculator.calculateDailyOvertime(duty, 440);
      expect(ot, equals(60)); // 1 hour OT
    });

    test('Calculate Duty Minutes for Shift B (Evening)', () {
      // Shift B: 16:40 to 00:00 (Total 7h 20m = 440m)
      final duty = DutyCalculator.calculateDutyMinutes('16:40', '00:00');
      expect(duty, equals(440));
      
      final ot = DutyCalculator.calculateDailyOvertime(duty, 440);
      expect(ot, equals(0)); // 0 hours OT
    });

    test('Calculate Duty Minutes for Shift C (Night)', () {
      // Shift C: 00:00 to 09:00 (Total 9h = 540m)
      final duty = DutyCalculator.calculateDutyMinutes('00:00', '09:00');
      expect(duty, equals(540));
      
      final ot = DutyCalculator.calculateDailyOvertime(duty, 440);
      expect(ot, equals(100)); // 1 hour 40 minutes OT
    });

    test('Custom Duty Calculation Examples', () {
      // Example 1: 10:00 Duty -> Normal 7:20, OT 2:40 (160 mins)
      final duty1 = DutyCalculator.calculateDutyMinutes('10:00', '20:00'); // 10h = 600 mins
      expect(duty1, equals(600));
      final ot1 = DutyCalculator.calculateDailyOvertime(duty1, 440);
      expect(ot1, equals(160)); // 160 mins = 2h 40m
      expect(DutyCalculator.minutesToTimeString(ot1), equals('02:40'));

      // Example 2: 24:00 Duty -> Normal 7:20, OT 16:40 (1000 mins)
      final duty2 = 24 * 60; // 1440 mins
      final ot2 = DutyCalculator.calculateDailyOvertime(duty2, 440);
      expect(ot2, equals(1000)); // 1000 mins = 16h 40m
      expect(DutyCalculator.minutesToTimeString(ot2), equals('16:40'));
    });

    test('CO Generation and Carry Forward OT Balance Accumulation', () {
      // Scenario:
      // Day 1: Earning 60 mins OT. Remaining accumulator = 0.
      var res = DutyCalculator.processAccumulatedOt(0, 60);
      expect(res['coGenerated'], equals(0));
      expect(res['remainingOtMinutes'], equals(60));

      // Day 2: Earning 100 mins OT. Previous remaining = 60.
      res = DutyCalculator.processAccumulatedOt(60, 100);
      expect(res['coGenerated'], equals(0));
      expect(res['remainingOtMinutes'], equals(160));

      // Day 3: Earning 280 mins OT. Previous remaining = 160. Total = 440.
      res = DutyCalculator.processAccumulatedOt(160, 280);
      expect(res['coGenerated'], equals(1)); // 1 CO generated
      expect(res['remainingOtMinutes'], equals(0)); // 0 remaining OT

      // Day 4: Working 24h custom duty, earning 1000 mins OT. Previous remaining = 0.
      res = DutyCalculator.processAccumulatedOt(0, 1000);
      expect(res['coGenerated'], equals(2)); // 2 COs generated (880 mins)
      expect(res['remainingOtMinutes'], equals(120)); // 120 mins carry-forward
    });
  });
}
