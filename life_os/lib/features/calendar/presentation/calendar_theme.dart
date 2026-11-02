import 'package:flutter/material.dart';

/// Sistema de diseño y paleta de colores para el Workspace de Calendario en Dark Mode.
///
/// Cumple con las especificaciones del documento de diseño:
/// - Fondo principal: #111318
/// - Fondo barra lateral: #171A21
/// - Fondo paneles: #1C2029
/// - Superficies elevadas: #252A35
/// - Bordes: #2D3340
/// - Tipografía: #F1F3F7 (Primaria), #9299A8 (Secundaria), #626A79 (Deshabilitada)
/// - Acento principal: #8B83F7
/// - Categorías: Personal (#A78BFA), Trabajo (#60A5FA), Estudios (#FBBF24), Salud (#34D399), Otro (#F472B6)
class CalendarTheme {
  const CalendarTheme._();

  // Fondos
  static const Color mainBg = Color(0xFF111318);
  static const Color sidebarBg = Color(0xFF171A21);
  static const Color panelBg = Color(0xFF1C2029);
  static const Color elevatedSurface = Color(0xFF252A35);
  static const Color hoverSurface = Color(0xFF2D3342);

  // Bordes
  static const Color border = Color(0xFF2D3340);
  static const Color borderSubtle = Color(0xFF222733);
  static const Color borderAccent = Color(0xFF4A4480);

  // Tipografía
  static const Color textPrimary = Color(0xFFF1F3F7);
  static const Color textSecondary = Color(0xFF9299A8);
  static const Color textDisabled = Color(0xFF626A79);

  // Acento
  static const Color accent = Color(0xFF8B83F7);
  static const Color accentLight = Color(0xFFA59EF9);
  static const Color accentMuted = Color(0x268B83F7); // 15% opacidad

  // Categorías de eventos
  static const Color catPersonal = Color(0xFFA78BFA);
  static const Color catWork = Color(0xFF60A5FA);
  static const Color catStudies = Color(0xFFFBBF24);
  static const Color catHealth = Color(0xFF34D399);
  static const Color catOther = Color(0xFFF472B6);

  static const List<String> allCategories = [
    'Personal',
    'Trabajo',
    'Estudios',
    'Salud',
    'Otro',
  ];

  /// Obtiene el color correspondiente a la categoría del evento.
  static Color colorForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'trabajo':
      case 'work':
      case 'laboral':
        return catWork;
      case 'estudios':
      case 'studies':
      case 'estudio':
      case 'universidad':
        return catStudies;
      case 'salud':
      case 'health':
      case 'médico':
      case 'medico':
        return catHealth;
      case 'otro':
      case 'other':
      case 'general':
        return catOther;
      case 'personal':
      default:
        return catPersonal;
    }
  }

  /// Color de fondo translúcido para tarjetas e indicadores.
  static Color backgroundForCategory(String category, {double opacity = 0.14}) {
    return colorForCategory(category).withValues(alpha: opacity);
  }

  /// Color de borde para la categoría.
  static Color borderForCategory(String category, {double opacity = 0.35}) {
    return colorForCategory(category).withValues(alpha: opacity);
  }

  /// Ícono representativo para cada categoría.
  static IconData iconForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'trabajo':
      case 'work':
        return Icons.business_center_outlined;
      case 'estudios':
      case 'studies':
        return Icons.school_outlined;
      case 'salud':
      case 'health':
        return Icons.spa_outlined;
      case 'otro':
      case 'other':
        return Icons.bookmark_border_rounded;
      case 'personal':
      default:
        return Icons.person_outline_rounded;
    }
  }

  // --- Helpers de Fecha y Formato en Español (Zero-dependency & Safe) ---

  static const List<String> months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const List<String> monthsShort = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  static const List<String> weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const List<String> weekdaysShort = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  /// Capitaliza la primera letra de un texto.
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Retorna el nombre del mes con su año, ej: "Noviembre 2026".
  static String formatMonthYear(DateTime date) {
    final mIndex = (date.month - 1).clamp(0, 11);
    return '${months[mIndex]} ${date.year}';
  }

  /// Retorna el día de la semana completo, ej: "Lunes".
  static String formatWeekday(DateTime date) {
    final wIndex = (date.weekday - 1).clamp(0, 6);
    return weekdays[wIndex];
  }

  /// Retorna el día de la semana abreviado, ej: "LUN".
  static String formatWeekdayShort(DateTime date, {bool uppercase = false}) {
    final wIndex = (date.weekday - 1).clamp(0, 6);
    final val = weekdaysShort[wIndex];
    return uppercase ? val.toUpperCase() : val;
  }

  /// Retorna el nombre del mes abreviado, ej: "Nov".
  static String formatMonthShort(DateTime date) {
    final mIndex = (date.month - 1).clamp(0, 11);
    return monthsShort[mIndex];
  }

  /// Retorna fecha en formato día y mes abreviado, ej: "2 Nov".
  static String formatDayMonthShort(DateTime date) {
    return '${date.day} ${formatMonthShort(date)}';
  }

  /// Retorna fecha en formato día, mes abreviado y año, ej: "2 Nov 2026".
  static String formatDayMonthYearShort(DateTime date) {
    return '${date.day} ${formatMonthShort(date)} ${date.year}';
  }

  /// Retorna fecha completa con día de la semana, ej: "Lunes, 2 de Noviembre de 2026".
  static String formatFullDateWithWeekday(DateTime date) {
    final mIndex = (date.month - 1).clamp(0, 11);
    return '${formatWeekday(date)}, ${date.day} de ${months[mIndex]} de ${date.year}';
  }

  /// Retorna fecha con día de la semana sin año o con año, ej: "Lunes, 2 de Noviembre".
  static String formatDayMonth(DateTime date) {
    final mIndex = (date.month - 1).clamp(0, 11);
    return '${date.day} de ${months[mIndex]}';
  }

  /// Retorna hora en formato militar HH:mm, ej: "09:05".
  static String formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Retorna rango de horas, ej: "09:00 - 10:30".
  static String formatTimeRange(DateTime start, DateTime end) {
    return '${formatTime(start)} - ${formatTime(end)}';
  }
}
