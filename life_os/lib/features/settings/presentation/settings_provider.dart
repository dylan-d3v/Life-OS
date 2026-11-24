import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias configurables del sistema por dispositivo (Fase 4 y Fase 5 - F1).
class AppSettingsState {
  final bool kevFabVisible;
  final bool notificationsEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final String notificationTone;

  const AppSettingsState({
    this.kevFabVisible = true,
    this.notificationsEnabled = true,
    this.dailyReminderHour = 9,
    this.dailyReminderMinute = 0,
    this.notificationTone = 'default',
  });

  String get formattedReminderTime =>
      '${dailyReminderHour.toString().padLeft(2, '0')}:${dailyReminderMinute.toString().padLeft(2, '0')}';

  AppSettingsState copyWith({
    bool? kevFabVisible,
    bool? notificationsEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    String? notificationTone,
  }) {
    return AppSettingsState(
      kevFabVisible: kevFabVisible ?? this.kevFabVisible,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      notificationTone: notificationTone ?? this.notificationTone,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  static const String _kKevFabVisibleKey = 'life_os_setting_kev_fab_visible';
  static const String _kNotificationsEnabledKey =
      'life_os_setting_notifications_enabled';
  static const String _kDailyReminderHourKey =
      'life_os_setting_daily_reminder_hour';
  static const String _kDailyReminderMinuteKey =
      'life_os_setting_daily_reminder_minute';
  static const String _kNotificationToneKey =
      'life_os_setting_notification_tone';

  @override
  AppSettingsState build() {
    _loadFromPrefs();
    return const AppSettingsState();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        kevFabVisible: prefs.getBool(_kKevFabVisibleKey) ?? true,
        notificationsEnabled: prefs.getBool(_kNotificationsEnabledKey) ?? true,
        dailyReminderHour: prefs.getInt(_kDailyReminderHourKey) ?? 9,
        dailyReminderMinute: prefs.getInt(_kDailyReminderMinuteKey) ?? 0,
        notificationTone: prefs.getString(_kNotificationToneKey) ?? 'default',
      );
    } catch (_) {}
  }

  Future<void> setKevFabVisible(bool visible) async {
    state = state.copyWith(kevFabVisible: visible);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kKevFabVisibleKey, visible);
    } catch (_) {}
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNotificationsEnabledKey, enabled);
    } catch (_) {}
  }

  Future<void> setDailyReminderTime(int hour, int minute) async {
    state = state.copyWith(
      dailyReminderHour: hour,
      dailyReminderMinute: minute,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDailyReminderHourKey, hour);
      await prefs.setInt(_kDailyReminderMinuteKey, minute);
    } catch (_) {}
  }

  Future<void> setNotificationTone(String tone) async {
    state = state.copyWith(notificationTone: tone);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kNotificationToneKey, tone);
    } catch (_) {}
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(
  AppSettingsNotifier.new,
);
