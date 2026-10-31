import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/calendar_event_item.dart';
import 'calendar_provider.dart';

/// Vista principal del Módulo de Calendario con cifrado E2EE.
class CalendarView extends ConsumerWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredEvents = ref.watch(filteredCalendarEventsProvider);
    final activeFilter = ref.watch(calendarFilterProvider);

    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendario y Agenda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Planificación de eventos y compromisos con cifrado de extremo a extremo',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _openEventDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Evento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Filtros temporales ──
          Row(
            children: [
              _FilterChip(
                label: 'Próximos',
                selected: activeFilter == CalendarFilter.upcoming,
                onTap: () => ref
                    .read(calendarFilterProvider.notifier)
                    .setFilter(CalendarFilter.upcoming),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Todos',
                selected: activeFilter == CalendarFilter.all,
                onTap: () => ref
                    .read(calendarFilterProvider.notifier)
                    .setFilter(CalendarFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pasados',
                selected: activeFilter == CalendarFilter.past,
                onTap: () => ref
                    .read(calendarFilterProvider.notifier)
                    .setFilter(CalendarFilter.past),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                tooltip: 'Recargar eventos',
                onPressed: () =>
                    ref.read(calendarEventListProvider.notifier).refresh(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Lista de Eventos ──
          Expanded(
            child: filteredEvents.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 12),
                    const Text('Error al cargar eventos',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(calendarEventListProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return _buildEmptyState(activeFilter);
                }
                return ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _EventCard(
                      event: event,
                      onEdit: () =>
                          _openEventDialog(context, ref, event: event),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(CalendarFilter filter) {
    final message = switch (filter) {
      CalendarFilter.upcoming =>
        'No tienes eventos próximos programados.\n¡Agenda uno nuevo!',
      CalendarFilter.all =>
        'No hay eventos registrados aún.\nCrea tu primer evento cifrado.',
      CalendarFilter.past => 'No tienes eventos pasados registrados.',
    };

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_note_outlined,
              size: 56,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEventDialog(BuildContext context, WidgetRef ref,
      {CalendarEventItem? event}) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _CalendarEventEditorDialog(ref: ref, initialEvent: event),
    );
  }
}

// =============================================================================
// Widget: Chip de Filtro
// =============================================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? const Color(0xFF0284C7) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Widget: Tarjeta de Evento
// =============================================================================

class _EventCard extends ConsumerWidget {
  const _EventCard({
    required this.event,
    required this.onEdit,
  });

  final CalendarEventItem event;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isPast = event.endTime.isBefore(now);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPast
              ? const Color(0xFF334155)
              : const Color(0xFF38BDF8).withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: Fecha y hora
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd/MM').format(event.startTime),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.isAllDay
                            ? 'Todo el día'
                            : '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Columna central: Detalles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title.isNotEmpty
                                  ? event.title
                                  : 'Sin título',
                              style: TextStyle(
                                color: isPast
                                    ? const Color(0xFF94A3B8)
                                    : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (event.isAllDay) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFF0284C7)),
                              ),
                              child: const Text(
                                'Día Completo',
                                style: TextStyle(
                                    color: Color(0xFF38BDF8), fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (event.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          event.description,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Columna derecha: Acción de eliminar
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Eliminar evento',
                  splashRadius: 18,
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar evento',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar el evento "${event.title}"? Los datos se marcarán como eliminados.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(calendarEventListProvider.notifier)
                  .deleteEvent(event.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Dialog: Editor de Evento
// =============================================================================

class _CalendarEventEditorDialog extends ConsumerStatefulWidget {
  const _CalendarEventEditorDialog({
    required this.ref,
    this.initialEvent,
  });

  final WidgetRef ref;
  final CalendarEventItem? initialEvent;

  @override
  ConsumerState<_CalendarEventEditorDialog> createState() =>
      _CalendarEventEditorDialogState();
}

class _CalendarEventEditorDialogState
    extends ConsumerState<_CalendarEventEditorDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locCtrl;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  late bool _isAllDay;
  bool _isLoading = false;

  bool get _isEditing => widget.initialEvent != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initialEvent;
    final now = DateTime.now();

    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _descCtrl = TextEditingController(text: init?.description ?? '');
    _locCtrl = TextEditingController(text: init?.location ?? '');
    _isAllDay = init?.isAllDay ?? false;

    _startDate = init?.startTime ?? now;
    _startTime = init != null
        ? TimeOfDay(hour: init.startTime.hour, minute: init.startTime.minute)
        : TimeOfDay(hour: now.hour, minute: 0);

    _endDate = init?.endTime ?? now.add(const Duration(hours: 1));
    _endTime = init != null
        ? TimeOfDay(hour: init.endTime.hour, minute: init.endTime.minute)
        : TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 20),
          const SizedBox(width: 8),
          Text(
            _isEditing ? 'Editar Evento Cifrado' : 'Nuevo Evento Cifrado',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                autofocus: !_isEditing,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Título del evento',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _locCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Ubicación o enlace',
                  prefixIcon: const Icon(Icons.location_on_outlined,
                      size: 18, color: Color(0xFF94A3B8)),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _descCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Descripción / Notas',
                  alignLabelWithHint: true,
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Checkbox Todo el día
              Row(
                children: [
                  Checkbox(
                    value: _isAllDay,
                    activeColor: const Color(0xFF0284C7),
                    checkColor: Colors.white,
                    onChanged: (val) =>
                        setState(() => _isAllDay = val ?? false),
                  ),
                  const Text('Evento de todo el día',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),

              // Fecha y Hora de Inicio
              Row(
                children: [
                  const SizedBox(
                    width: 70,
                    child: Text('Inicio:',
                        style: TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                  ),
                  if (!_isAllDay) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.access_time, size: 14),
                      label: Text(
                        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ],
              ),

              // Fecha y Hora de Fin
              Row(
                children: [
                  const SizedBox(
                    width: 70,
                    child: Text('Fin:',
                        style: TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                  ),
                  if (!_isAllDay) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.access_time, size: 14),
                      label: Text(
                        '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 14, color: Color(0xFF22C55E)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'El título, ubicación y descripción se cifran con AES-256-GCM localmente.',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEditing ? 'Guardar Cambios' : 'Crear Evento'),
        ),
      ],
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final start = _combine(_startDate, _isAllDay ? const TimeOfDay(hour: 0, minute: 0) : _startTime);
    final end = _combine(_endDate, _isAllDay ? const TimeOfDay(hour: 23, minute: 59) : _endTime);

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha y hora de fin debe ser posterior o igual a la de inicio.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final updated = widget.initialEvent!.copyWith(
          title: title,
          description: _descCtrl.text.trim(),
          location: _locCtrl.text.trim(),
          startTime: start,
          endTime: end,
          isAllDay: _isAllDay,
          updatedAt: DateTime.now(),
        );
        await ref
            .read(calendarEventListProvider.notifier)
            .updateEvent(updated);
      } else {
        await ref.read(calendarEventListProvider.notifier).addEvent(
              title: title,
              startTime: start,
              endTime: end,
              isAllDay: _isAllDay,
              description: _descCtrl.text.trim(),
              location: _locCtrl.text.trim(),
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar evento: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
