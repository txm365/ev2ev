// lib/utils/extensions.dart
import 'formatters.dart';

extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  String toTitleCase() {
    return split(' ')
        .map((word) => word.capitalize())
        .join(' ');
  }
}

extension DateTimeExtensions on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year &&
           month == other.month &&
           day == other.day;
  }

  bool isToday() {
    return isSameDay(DateTime.now());
  }

  bool isTomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return isSameDay(tomorrow);
  }

  String toRelativeString() {
    if (isToday()) {
      return 'Today';
    } else if (isTomorrow()) {
      return 'Tomorrow';
    } else {
      return Formatters.formatDate(this);
    }
  }
}

extension DoubleExtensions on double {
  String toEnergyString() => Formatters.formatEnergy(this);
  String toCurrencyString() => Formatters.formatCurrency(this);
  String toDistanceString() => Formatters.formatDistance(this);
}