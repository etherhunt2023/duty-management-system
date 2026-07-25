import 'package:intl/intl.dart';

class DutyCalculator {
  DutyCalculator._();

  static const int normalDutyMinutes = 440; // 07:20 in minutes

  // Helper to parse time strings "HH:MM" into minutes from midnight
  static int timeStringToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return hours * 60 + minutes;
      }
    } catch (e) {
      // Return 0 on parsing error
    }
    return 0;
  }

  // Format minutes into "HH:mm" string representation
  static String minutesToTimeString(int totalMinutes) {
    if (totalMinutes < 0) totalMinutes = 0;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  // Parse check-in and check-out to calculate total worked duty minutes
  static int calculateDutyMinutes(String checkInStr, String checkOutStr) {
    if (checkInStr.isEmpty || checkOutStr.isEmpty) return 0;
    
    final checkIn = timeStringToMinutes(checkInStr);
    var checkOut = timeStringToMinutes(checkOutStr);
    
    // Handle overnight shifts (e.g., Check-in 16:40, Check-out 00:00 or Check-in 00:00, Check-out 09:00)
    if (checkOut < checkIn) {
      checkOut += 24 * 60; // Add 24 hours in minutes
    }
    
    return checkOut - checkIn;
  }

  // Calculate daily overtime (OT = Total Duty - 07:20, never negative)
  static int calculateDailyOvertime(int dutyMinutes, int shiftNormalDuty) {
    final ot = dutyMinutes - shiftNormalDuty;
    return ot > 0 ? ot : 0;
  }

  // Calculate CO generated and remaining carry-forward OT from running accumulator
  // Rule: every 440 minutes (07:20) = 1 CO
  static Map<String, int> processAccumulatedOt(int previousAccumulatedOt, int newOtMinutes) {
    final totalAccumulated = previousAccumulatedOt + newOtMinutes;
    
    // Handle floor division for negative or positive values
    final coGenerated = totalAccumulated ~/ normalDutyMinutes;
    final remainingOt = totalAccumulated % normalDutyMinutes;

    return {
      'coGenerated': coGenerated > 0 ? coGenerated : 0,
      'remainingOtMinutes': remainingOt >= 0 ? remainingOt : 0,
    };
  }
}
