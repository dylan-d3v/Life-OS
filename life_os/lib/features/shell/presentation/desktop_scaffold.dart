import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation_provider.dart';
import 'widgets/sidebar.dart';
import '../../tasks/presentation/tasks_view.dart';
import '../../notes/presentation/notes_view.dart';
import '../../calendar/presentation/calendar_view.dart';
import '../../finance/presentation/finance_view.dart';
import '../../projects/presentation/projects_view.dart';
import '../../settings/presentation/settings_view.dart';

class DesktopScaffold extends ConsumerWidget {
  const DesktopScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSection = ref.watch(activeSectionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Barra Lateral (Sidebar)
          const Sidebar(),

          // 2. Área de Contenido Principal
          Expanded(
            child: Column(
              children: [
                // Barra Superior (Header Bar)
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B), // Slate 800
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        activeSection.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.cloud_done_outlined,
                                    size: 16, color: Color(0xFF34D399)),
                                SizedBox(width: 8),
                                Text(
                                  'Conectado a Supabase',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Vista Activa
                Expanded(
                  child: _buildActiveView(activeSection),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(NavSection section) {
    switch (section) {
      case NavSection.tasks:
        return const TasksView();
      case NavSection.notes:
        return const NotesView();
      case NavSection.calendar:
        return const CalendarView();
      case NavSection.finance:
        return const FinanceView();
      case NavSection.projects:
        return const ProjectsView();
      case NavSection.settings:
        return const SettingsView();
    }
  }
}
