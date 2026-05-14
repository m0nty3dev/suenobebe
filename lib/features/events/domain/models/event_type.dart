import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';

enum EventType {
  morningWake,
  nap,
  bedtime,
  nightWake,
  nursing,
  bottle;

  String get label {
    switch (this) {
      case EventType.morningWake:
        return 'Despertar mañana';
      case EventType.nap:
        return 'Siesta';
      case EventType.bedtime:
        return 'Ir a la cama';
      case EventType.nightWake:
        return 'Despertar nocturno';
      case EventType.nursing:
        return 'Lactancia';
      case EventType.bottle:
        return 'Biberón';
    }
  }

  String get firestoreValue {
    switch (this) {
      case EventType.morningWake:
        return 'morning_wake';
      case EventType.nap:
        return 'nap';
      case EventType.bedtime:
        return 'bedtime';
      case EventType.nightWake:
        return 'night_wake';
      case EventType.nursing:
        return 'nursing';
      case EventType.bottle:
        return 'bottle';
    }
  }

  static EventType fromFirestore(String value) {
    switch (value) {
      case 'morning_wake':
        return EventType.morningWake;
      case 'nap':
        return EventType.nap;
      case 'bedtime':
        return EventType.bedtime;
      case 'night_wake':
        return EventType.nightWake;
      case 'nursing':
        return EventType.nursing;
      case 'bottle':
        return EventType.bottle;
      default:
        throw ArgumentError('Unknown event type: $value');
    }
  }

  bool get isDuration {
    switch (this) {
      case EventType.morningWake:
      case EventType.bedtime:
        return false;
      default:
        return true;
    }
  }

  bool get isSleepRelated {
    switch (this) {
      case EventType.nap:
      case EventType.nightWake:
      case EventType.morningWake:
      case EventType.bedtime:
        return true;
      default:
        return false;
    }
  }

  bool get isFeedingRelated {
    return this == EventType.nursing || this == EventType.bottle;
  }

  Color get color {
    switch (this) {
      case EventType.morningWake:
        return AppColors.morningWakeColor;
      case EventType.nap:
        return AppColors.napColor;
      case EventType.bedtime:
        return AppColors.bedtimeColor;
      case EventType.nightWake:
        return AppColors.nightWakeColor;
      case EventType.nursing:
        return AppColors.nursingColor;
      case EventType.bottle:
        return AppColors.bottleColor;
    }
  }

  PhosphorIconData get icon {
    switch (this) {
      case EventType.morningWake:
        return PhosphorIconsRegular.sun;
      case EventType.nap:
        return PhosphorIconsRegular.moon;
      case EventType.bedtime:
        return PhosphorIconsRegular.bed;
      case EventType.nightWake:
        return PhosphorIconsRegular.moonStars;
      case EventType.nursing:
        return PhosphorIconsRegular.baby;
      case EventType.bottle:
        return PhosphorIconsRegular.baby;
    }
  }
}
