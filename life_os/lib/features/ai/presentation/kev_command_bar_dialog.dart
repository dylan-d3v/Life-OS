import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/kev_action_dispatcher.dart';
import 'kev_command_bar_controller.dart';

/// Abre la barra de comandos modal de Kev en el escritorio.
Future<void> showKevCommandBar(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withAlpha(160),
    builder: (_) => const KevCommandBarDialog(),
  );
}

/// Diálogo modal flotante de la barra de comandos del Asistente Kev.
class KevCommandBarDialog extends ConsumerStatefulWidget {
  const KevCommandBarDialog({super.key});

  @override
  ConsumerState<KevCommandBarDialog> createState() =>
      _KevCommandBarDialogState();
}

class _KevCommandBarDialogState extends ConsumerState<KevCommandBarDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    ref.read(kevCommandBarProvider.notifier).executePrompt(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kevCommandBarProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Slate 800
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Encabezado de la barra
              _buildHeader(context),

              const Divider(color: Color(0xFF334155), height: 1),

              // 2. Campo de entrada principal
              _buildInputField(state.isProcessing),

              // 3. Tarjeta de resultado reciente
              if (state.lastResult != null)
                _buildResultCard(state.lastResult!),

              // 4. Sugerencias rápidas cuando no hay resultado
              if (state.lastResult == null && state.history.isEmpty)
                _buildQuickSuggestions(),

              // 5. Historial reciente
              if (state.history.isNotEmpty)
                _buildHistorySection(state.history),

              const Divider(color: Color(0xFF334155), height: 1),

              // 6. Pie con atajos de teclado
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Kev AI Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: const Text(
                  'TypeSafe E2EE',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Cerrar [Esc]',
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(bool isProcessing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.bolt_outlined,
            color: Color(0xFF818CF8),
            size: 22,
          ),
          hintText:
              'Escribe una orden (ej: "Crear tarea estudiar", "Gasté \$20 en gasolina")...',
          hintStyle:
              const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
          suffixIcon: isProcessing
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF818CF8)),
                    ),
                  ),
                )
              : IconButton(
                  key: const Key('kev_submit_button'),
                  tooltip: 'Enviar orden',
                  icon: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Color(0xFF818CF8),
                  ),
                  onPressed: _handleSubmit,
                ),
        ),
        onSubmitted: (_) => _handleSubmit(),
      ),
    );
  }

  Widget _buildResultCard(KevExecutionResult result) {
    final meta = _getActionMetadata(result.actionType, result.success);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: meta.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: meta.borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(meta.icon, color: meta.accentColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: meta.accentColor.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meta.label,
                        style: TextStyle(
                          color: meta.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 14, color: Color(0xFF94A3B8)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ref
                          .read(kevCommandBarProvider.notifier)
                          .clearLastResult(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.userMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    final suggestions = [
      'Anotar tarea estudiar matemáticas para mañana',
      'Gasté \$15 en almuerzo',
      'Reunión de proyecto mañana a las 3pm',
      'Nota rápida: recordatorio de compra',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sugerencias de órdenes:',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((text) {
              return ActionChip(
                backgroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFF334155)),
                label: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                  ),
                ),
                onPressed: () {
                  _controller.text = text;
                  _focusNode.requestFocus();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(List<KevCommandHistoryItem> history) {
    final recent = history.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comandos recientes de la sesión:',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...recent.map((item) {
            final meta = _getActionMetadata(
              item.result.actionType,
              item.result.success,
            );
            final timeStr = DateFormat('HH:mm').format(item.timestamp);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Icon(meta.icon, size: 14, color: meta.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.query,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                _KbdBadge(text: 'Enter'),
                SizedBox(width: 4),
                Text(
                  'enviar',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                SizedBox(width: 10),
                _KbdBadge(text: 'Esc'),
                SizedBox(width: 4),
                Text(
                  'cerrar',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            'Zero-Knowledge AES-256-GCM',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _ActionMeta _getActionMetadata(String actionType, bool success) {
    if (!success) {
      return const _ActionMeta(
        label: 'Error',
        icon: Icons.error_outline,
        accentColor: Color(0xFFEF4444),
        bgColor: Color(0x22EF4444),
        borderColor: Color(0x66EF4444),
      );
    }

    return switch (actionType) {
      'create_task' => const _ActionMeta(
          label: 'Tarea Creada',
          icon: Icons.check_circle_outline,
          accentColor: Color(0xFF38BDF8),
          bgColor: Color(0x2238BDF8),
          borderColor: Color(0x6638BDF8),
        ),
      'create_note' => const _ActionMeta(
          label: 'Nota Guardada',
          icon: Icons.description_outlined,
          accentColor: Color(0xFFA855F7),
          bgColor: Color(0x22A855F7),
          borderColor: Color(0x66A855F7),
        ),
      'create_project' => const _ActionMeta(
          label: 'Proyecto Creado',
          icon: Icons.folder_outlined,
          accentColor: Color(0xFF34D399),
          bgColor: Color(0x2234D399),
          borderColor: Color(0x6634D399),
        ),
      'create_calendar_event' => const _ActionMeta(
          label: 'Evento Agendado',
          icon: Icons.event_outlined,
          accentColor: Color(0xFFFB923C),
          bgColor: Color(0x22FB923C),
          borderColor: Color(0x66FB923C),
        ),
      'log_finance' => const _ActionMeta(
          label: 'Finanzas Registradas',
          icon: Icons.attach_money,
          accentColor: Color(0xFF4ADE80),
          bgColor: Color(0x224ADE80),
          borderColor: Color(0x664ADE80),
        ),
      'query_summary' => const _ActionMeta(
          label: 'Consulta Realizada',
          icon: Icons.insights_outlined,
          accentColor: Color(0xFF818CF8),
          bgColor: Color(0x22818CF8),
          borderColor: Color(0x66818CF8),
        ),
      _ => const _ActionMeta(
          label: 'Acción Ejecutada',
          icon: Icons.info_outline,
          accentColor: Color(0xFF94A3B8),
          bgColor: Color(0x2294A3B8),
          borderColor: Color(0x6694A3B8),
        ),
    };
  }
}

class _ActionMeta {
  final String label;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;

  const _ActionMeta({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
  });
}

class _KbdBadge extends StatelessWidget {
  final String text;

  const _KbdBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
