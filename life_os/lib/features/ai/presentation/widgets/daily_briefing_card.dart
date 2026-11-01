import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../ai_providers.dart';
import '../kev_command_bar_dialog.dart';

/// Tarjeta visual del Briefing Diario Inteligente de Kev.
///
/// Muestra un resumen matutino de tareas pendientes, eventos de calendario y
/// gastos del día calculados y descifrados localmente con E2EE.
class DailyBriefingCard extends ConsumerWidget {
  const DailyBriefingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(dailyBriefingProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B), // Slate 800
            Color(0xFF0F172A), // Slate 900
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: briefingAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(
              color: Color(0xFF818CF8),
              strokeWidth: 2.5,
            ),
          ),
        ),
        error: (error, _) => Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No se pudo cargar el briefing diario: $error',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          ],
        ),
        data: (briefing) {
          final dateStr = DateFormat('EEEE, d MMMM yyyy').format(briefing.date);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado del Briefing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFFB923C)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.wb_sunny_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Briefing Diario Kev',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Recargar briefing',
                        icon: const Icon(
                          Icons.refresh,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                        onPressed: () => ref.refresh(dailyBriefingProvider),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: const Color(0xFF818CF8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFF475569)),
                          ),
                        ),
                        onPressed: () => showKevCommandBar(context),
                        icon: const Icon(Icons.auto_awesome, size: 14),
                        label: const Text(
                          'Kev (Ctrl + K)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Si la bóveda está bloqueada, advertir amigablemente
              if (briefing.isLocked)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x22F59E0B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x66F59E0B)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline,
                          color: Color(0xFFF59E0B), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bóveda de seguridad bloqueada. Inicia sesión con tu clave maestra para consultar tu resumen.',
                          style: TextStyle(
                              color: Color(0xFFFDE68A), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Píldoras de métricas destacadas
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _MetricPill(
                      icon: Icons.check_circle_outline,
                      label:
                          '${briefing.pendingTasks.length} Tareas pendientes',
                      extra: briefing.urgentTasks.isNotEmpty
                          ? '(${briefing.urgentTasks.length} urgentes)'
                          : null,
                      color: const Color(0xFF38BDF8),
                    ),
                    _MetricPill(
                      icon: Icons.event_outlined,
                      label: '${briefing.todayEvents.length} Eventos hoy',
                      color: const Color(0xFFFB923C),
                    ),
                    _MetricPill(
                      icon: Icons.attach_money,
                      label:
                          'Gastos hoy: \$${briefing.todayExpenses.toStringAsFixed(2)}',
                      color: const Color(0xFF4ADE80),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Resumen narrativo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    briefing.formattedSummary,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? extra;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.label,
    this.extra,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(width: 4),
            Text(
              extra!,
              style: TextStyle(
                color: color.withAlpha(200),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

