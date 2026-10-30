import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NavSection {
  tasks,
  notes,
  calendar,
  finance,
  projects,
  settings,
}

extension NavSectionX on NavSection {
  String get title {
    switch (this) {
      case NavSection.tasks:
        return 'Tareas';
      case NavSection.notes:
        return 'Notas Diarias';
      case NavSection.calendar:
        return 'Calendario';
      case NavSection.finance:
        return 'Finanzas';
      case NavSection.projects:
        return 'Proyectos';
      case NavSection.settings:
        return 'Ajustes';
    }
  }
}

/// Notificador moderno de Riverpod 3 para la sección activa.
class ActiveSectionNotifier extends Notifier<NavSection> {
  @override
  NavSection build() => NavSection.tasks;

  void select(NavSection section) => state = section;
}

final activeSectionProvider =
    NotifierProvider<ActiveSectionNotifier, NavSection>(ActiveSectionNotifier.new);

/// Notificador moderno de Riverpod 3 para controlar si el sidebar está colapsado.
class SidebarCollapseNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setCollapsed(bool value) => state = value;
}

final isSidebarCollapsedProvider =
    NotifierProvider<SidebarCollapseNotifier, bool>(SidebarCollapseNotifier.new);
