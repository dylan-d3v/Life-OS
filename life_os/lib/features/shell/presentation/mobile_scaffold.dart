import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai/presentation/kev_command_bar_dialog.dart';
import '../../ai/presentation/today_briefing_view.dart';
import '../../calendar/presentation/calendar_view.dart';
import '../../finance/presentation/finance_view.dart';
import '../../notes/presentation/notes_view.dart';
import '../../projects/presentation/projects_view.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../settings/presentation/settings_view.dart';
import '../../tasks/presentation/tasks_view.dart';
import 'navigation_provider.dart';

/// Shell de interfaz optimizado para smartphones y pantallas táctiles (Thumb-Friendly).
///
/// Implementa:
/// 1. NavigationBar inferior Material 3 accesible con una sola mano.
/// 2. Floating Action Button (FAB) de Kev Asistente para captura rápida por voz o texto.
/// 3. Menú modal inferior ("Más") para secciones secundarias (Calendario, Proyectos, Ajustes).
/// 4. Barra superior compacta con estado de sincronización E2EE y título.
class MobileScaffold extends ConsumerWidget {
  const MobileScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSection = ref.watch(activeSectionProvider);
    final appSettings = ref.watch(appSettingsProvider);

    // Mapeo del índice de navegación inferior (0: Hoy, 1: Tareas, 2: Notas, 3: Finanzas, 4: Más)
    final selectedIndex = switch (activeSection) {
      NavSection.today => 0,
      NavSection.tasks => 1,
      NavSection.notes => 2,
      NavSection.finance => 3,
      NavSection.calendar || NavSection.projects || NavSection.settings => 4,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: const Color(0xFF1E293B), // Slate 800
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Center(
                  child: Text(
                    'L',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activeSection.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            // Indicador de Sincronización E2EE
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 13, color: Color(0xFF34D399)),
                  SizedBox(width: 5),
                  Text(
                    'E2EE',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildActiveView(activeSection),
        ),
      ),
      // ── Botón Flotante de Captura Rápida (Kev AI) ──
      floatingActionButton: appSettings.kevFabVisible
          ? FloatingActionButton(
              key: const Key('kev_mobile_fab'),
              onPressed: () => showKevCommandBar(context),
              backgroundColor: const Color(0xFF818CF8),
              foregroundColor: Colors.white,
              elevation: 6,
              tooltip: 'Asistente Kev (Captura rápida)',
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 26, color: Colors.white),
              ),
            )
          : null,
      // ── Barra de Navegación Inferior M3 ──
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF334155), width: 1),
          ),
        ),
        child: NavigationBar(
          backgroundColor: const Color(0xFF1E293B),
          indicatorColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                ref
                    .read(activeSectionProvider.notifier)
                    .select(NavSection.today);
                break;
              case 1:
                ref
                    .read(activeSectionProvider.notifier)
                    .select(NavSection.tasks);
                break;
              case 2:
                ref
                    .read(activeSectionProvider.notifier)
                    .select(NavSection.notes);
                break;
              case 3:
                ref
                    .read(activeSectionProvider.notifier)
                    .select(NavSection.finance);
                break;
              case 4:
                _showMoreOptionsBottomSheet(context, ref);
                break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined, color: Color(0xFF94A3B8)),
              selectedIcon:
                  Icon(Icons.wb_sunny, color: Color(0xFFF59E0B)),
              label: 'Hoy',
            ),
            NavigationDestination(
              icon: Icon(Icons.check_circle_outline, color: Color(0xFF94A3B8)),
              selectedIcon:
                  Icon(Icons.check_circle, color: Color(0xFF38BDF8)),
              label: 'Tareas',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined, color: Color(0xFF94A3B8)),
              selectedIcon:
                  Icon(Icons.description, color: Color(0xFF38BDF8)),
              label: 'Notas',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined,
                  color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.account_balance_wallet,
                  color: Color(0xFF22C55E)),
              label: 'Finanzas',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.more_horiz, color: Color(0xFF818CF8)),
              label: 'Más',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveView(NavSection section) {
    switch (section) {
      case NavSection.today:
        return const TodayBriefingView(key: ValueKey('view_today'));
      case NavSection.tasks:
        return const TasksView(key: ValueKey('view_tasks'));
      case NavSection.notes:
        return const NotesView(key: ValueKey('view_notes'));
      case NavSection.calendar:
        return const CalendarView(key: ValueKey('view_calendar'));
      case NavSection.finance:
        return const FinanceView(key: ValueKey('view_finance'));
      case NavSection.projects:
        return const ProjectsView(key: ValueKey('view_projects'));
      case NavSection.settings:
        return const SettingsView(key: ValueKey('view_settings'));
    }
  }

  void _showMoreOptionsBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Más Secciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined,
                      color: Color(0xFF38BDF8)),
                  title: const Text('Calendario',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Agenda y eventos programados',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: Color(0xFF64748B)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref
                        .read(activeSectionProvider.notifier)
                        .select(NavSection.calendar);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_outlined,
                      color: Color(0xFF38BDF8)),
                  title: const Text('Proyectos y Metas',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Grandes iniciativas y objetivos',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: Color(0xFF64748B)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref
                        .read(activeSectionProvider.notifier)
                        .select(NavSection.projects);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined,
                      color: Color(0xFF94A3B8)),
                  title: const Text('Ajustes del Sistema',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Bóveda local, cuenta y sincronización',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: Color(0xFF64748B)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref
                        .read(activeSectionProvider.notifier)
                        .select(NavSection.settings);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
