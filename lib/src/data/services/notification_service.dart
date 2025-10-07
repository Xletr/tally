import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/formatters.dart';
import '../../domain/entities/budget_insights.dart';
import '../../domain/entities/budget_month.dart';
import '../../domain/entities/budget_settings.dart';
import '../../domain/logic/spending_guidance.dart';
import 'native_timezone.dart';

class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    final settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    tz.initializeTimeZones();
    final timeZoneName = await loadLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    _initialized = true;
  }

  Future<void> scheduleMonthlyReminders(
    BudgetMonth month,
    BudgetSettings settings,
  ) async {
    if (!_initialized || !settings.notificationsEnabled) return;

    final midMonthId = _notificationId(month.id, 1);
    final endMonthId = _notificationId(month.id, 2);

    await _plugin.cancel(midMonthId);
    await _plugin.cancel(endMonthId);

    if (settings.midMonthReminder) {
      final midTime = settings.midMonthReminderAt;
      final midDate = DateTime(
        month.year,
        month.month,
        min(15, month.cycleEnd.day),
        midTime.hour,
        midTime.minute,
      );
      final tzMid = tz.TZDateTime.from(midDate, tz.local);
      await _safeSchedule(
        id: midMonthId,
        title: 'Tally check-in',
        body:
            'You are halfway through the month. Review spending to stay on track.',
        dateTime: tzMid,
      );
    }

    if (settings.endOfMonthReminder) {
      final endTime = settings.endOfMonthReminderAt;
      final endDate = DateTime(
        month.year,
        month.month,
        month.cycleEnd.day,
        endTime.hour,
        endTime.minute,
      );
      final tzEnd = tz.TZDateTime.from(endDate, tz.local);
      await _safeSchedule(
        id: endMonthId,
        title: 'Month wrap-up',
        body: 'Close out ${_monthLabel(month)} and plan next month\'s budget.',
        dateTime: tzEnd,
      );
    }
  }

  Future<void> showOverspendAlert(
    BudgetMonth month,
    BudgetInsights insights,
    BudgetSettings settings,
  ) async {
    if (!_initialized ||
        !settings.notificationsEnabled ||
        !settings.overspendAlerts) {
      return;
    }
    if (insights.projectedOverspendPercent <= 5) {
      return;
    }

    final guidance = computeSpendingGuidance(
      month: month,
      insights: insights,
      now: DateTime.now(),
    );
    final targetDaily = guidance.savingsGap > 0
        ? guidance.savingsAwareDaily
        : guidance.breakEvenDaily;
    final avgLabel = formatCurrency(guidance.averageDailySpend);
    final targetLabel = formatCurrency(targetDaily);
    final percentLabel = insights.projectedOverspendPercent.toStringAsFixed(0);
    final savingsNote = guidance.savingsGap > 0
        ? ' Leave ${formatCurrency(guidance.savingsGap)} for savings to stay on goal.'
        : '';

    final id = _notificationId(month.id, 3);
    await _plugin.show(
      id,
      'Heads-up from Tally',
      'Averaging $avgLabel per day — aim for $targetLabel to avoid overspending (~$percentLabel% over plan).$savingsNote',
      _defaultDetails(),
    );
  }

  Future<void> cancelMonthNotifications(String monthId) async {
    if (!_initialized) return;
    for (var suffix = 1; suffix <= 3; suffix++) {
      await _plugin.cancel(_notificationId(monthId, suffix));
    }
  }

  NotificationDetails _defaultDetails() {
    const android = AndroidNotificationDetails(
      'tally_budget_channel',
      'Budget Alerts',
      channelDescription: 'Reminders to stay on top of your monthly inflow.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: ios);
  }

  Future<void> _safeSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime dateTime,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        dateTime,
        _defaultDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } on PlatformException catch (error) {
      if (error.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          dateTime,
          _defaultDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      } else {
        rethrow;
      }
    }
  }

  int _notificationId(String monthId, int slot) {
    final key = monthId.replaceAll('-', '');
    return int.parse('$key$slot');
  }

  String _monthLabel(BudgetMonth month) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }
}
