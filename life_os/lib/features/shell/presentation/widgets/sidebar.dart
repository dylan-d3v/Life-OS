import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/crypto_providers.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../navigation_provider.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSection = ref.watch(activeSectionProvider);
    final isCollapsed = ref.watch(isSidebarCollapsedProvider);
    final vault = ref.watch(keyVaultServiceProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final currentUser = authRepo.currentUser;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 76 : 240,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Slate 800
        border: Border(
          right: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Encabezado del Sidebar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!isCollapsed) ...[
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: Color(0xFF38BDF8), size: 24),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Life-OS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: isCollapsed ? 'Expandir barra' : 'Colapsar barra',
                  icon: Icon(
                    isCollapsed ? Icons.menu : Icons.menu_open,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: () {
                    ref.read(isSidebarCollapsedProvider.notifier).toggle();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          const SizedBox(height: 12),

          // Items de Navegación
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildNavItem(
                  ref: ref,
                  section: NavSection.tasks,
                  icon: Icons.check_circle_outline,
                  label: 'Tareas',
                  isActive: activeSection == NavSection.tasks,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  ref: ref,
                  section: NavSection.notes,
                  icon: Icons.description_outlined,
                  label: 'Notas',
                  isActive: activeSection == NavSection.notes,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  ref: ref,
                  section: NavSection.calendar,
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendario',
                  isActive: activeSection == NavSection.calendar,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  ref: ref,
                  section: NavSection.finance,
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Finanzas',
                  isActive: activeSection == NavSection.finance,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  ref: ref,
                  section: NavSection.projects,
                  icon: Icons.folder_outlined,
                  label: 'Proyectos',
                  isActive: activeSection == NavSection.projects,
                  isCollapsed: isCollapsed,
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFF334155)),
                const SizedBox(height: 16),
                _buildNavItem(
                  ref: ref,
                  section: NavSection.settings,
                  icon: Icons.settings_outlined,
                  label: 'Ajustes',
                  isActive: activeSection == NavSection.settings,
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
          ),

          // Pie del Sidebar: Estado E2EE y Usuario
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Column(
              children: [
                // Indicador E2EE
                Tooltip(
                  message: vault.isUnlocked
                      ? 'Bóveda E2EE Desbloqueada (AES-256)'
                      : 'Bóveda Bloqueada',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: vault.isUnlocked
                          ? const Color(0x2210B981)
                          : const Color(0x22EF4444),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: vault.isUnlocked
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          vault.isUnlocked
                              ? Icons.lock_open
                              : Icons.lock_outline,
                          size: 16,
                          color: vault.isUnlocked
                              ? const Color(0xFF34D399)
                              : const Color(0xFFF87171),
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              vault.isUnlocked ? 'E2EE Activo' : 'Bloqueado',
                              style: TextStyle(
                                color: vault.isUnlocked
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFF87171),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Perfil / Logout
                Row(
                  mainAxisAlignment: isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isCollapsed) ...[
                      Expanded(
                        child: Text(
                          currentUser?.email ?? 'Usuario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Cerrar Sesión',
                      icon: const Icon(Icons.logout,
                          size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        ref.read(authControllerProvider.notifier).signOut();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required WidgetRef ref,
    required NavSection section,
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCollapsed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(activeSectionProvider.notifier).select(section);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF0284C7) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : const Color(0xFFCBD5E1),
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
