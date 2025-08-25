// lib/utils/formatters.dart
import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_ZA',
    symbol: 'R',
    decimalDigits: 2,
  );

  static final NumberFormat _energyFormat = NumberFormat('#,##0.0');
  
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatEnergy(double energy) {
    return '${_energyFormat.format(energy)} kWh';
  }

  static String formatDistance(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).round()}m away';
    }
    return '${distance.toStringAsFixed(1)}km away';
  }

  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatTime(DateTime time) {
    return _timeFormat.format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    
    if (duration.inHours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
