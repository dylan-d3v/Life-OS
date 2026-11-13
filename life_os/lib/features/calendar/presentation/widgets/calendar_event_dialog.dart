import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/calendar_event_item.dart';
import '../calendar_provider.dart';
import '../calendar_theme.dart';

/// Diálogo modal estilizado para crear o editar eventos con cifrado E2EE.
class CalendarEventDialog extends ConsumerStatefulWidget {
  final CalendarEventItem? eventToEdit;
  final DateTime? initialDate;

  const CalendarEventDialog({
    super.key,
    this.eventToEdit,
    this.initialDate,
  });

  @override
  ConsumerState<CalendarEventDialog> createState() => _CalendarEventDialogState();
}

class _CalendarEventDialogState extends ConsumerState<CalendarEventDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  late String _selectedCategory;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isAllDay;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.eventToEdit;

    _titleController = TextEditingController(text: edit?.title ?? '');
    _descriptionController = TextEditingController(text: edit?.description ?? '');
    _locationController = TextEditingController(text: edit?.location ?? '');

    _selectedCategory = edit?.category ?? 'Personal';
    _isAllDay = edit?.isAllDay ?? false;

    if (edit != null) {
      _selectedDate = DateTime(edit.startTime.year, edit.startTime.month, edit.startTime.day);
      _startTime = TimeOfDay(hour: edit.startTime.hour, minute: edit.startTime.minute);
      _endTime = TimeOfDay(hour: edit.endTime.hour, minute: edit.endTime.minute);
    } else {
      final initial = widget.initialDate ?? DateTime.now();
      _selectedDate = DateTime(initial.year, initial.month, initial.day);
      _startTime = TimeOfDay(hour: initial.hour == 0 ? 9 : initial.hour, minute: 0);
      _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: CalendarTheme.accent,
              surface: CalendarTheme.panelBg,
              onSurface: CalendarTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: CalendarTheme.accent,
              surface: CalendarTheme.panelBg,
              onSurface: CalendarTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );

    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _isAllDay ? 23 : _endTime.hour,
      _isAllDay ? 59 : _endTime.minute,
    );

    if (!_isAllDay && endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La hora de fin debe ser posterior a la hora de inicio.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(calendarEventListProvider.notifier);
      if (widget.eventToEdit != null) {
        final updated = widget.eventToEdit!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          category: _selectedCategory,
          startTime: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          updatedAt: DateTime.now(),
        );
        await notifier.updateEvent(updated);
      } else {
        await notifier.addEvent(
          title: _titleController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          category: _selectedCategory,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el evento: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.eventToEdit == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CalendarTheme.panelBg,
        title: const Text('¿Eliminar evento?', style: TextStyle(color: CalendarTheme.textPrimary)),
        content: const Text(
          'Esta acción eliminará el evento de forma permanente.',
          style: TextStyle(color: CalendarTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: CalendarTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(calendarEventListProvider.notifier).deleteEvent(widget.eventToEdit!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventToEdit != null;
    final dialogTitle = isEditing ? 'Editar Evento Cifrado' : 'Nuevo Evento Cifrado';

    return Dialog(
      backgroundColor: CalendarTheme.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CalendarTheme.border, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Encabezado ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: CalendarTheme.accentMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: CalendarTheme.accentLight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          dialogTitle,
                          style: const TextStyle(
                            color: CalendarTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: CalendarTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: CalendarTheme.borderSubtle),
                const SizedBox(height: 14),

                // ── Formulario Scrollable ──
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título del evento
                        _buildFieldLabel('Título del evento'),
                        TextFormField(
                          controller: _titleController,
                          style: const TextStyle(color: CalendarTheme.textPrimary, fontSize: 13),
                          decoration: _inputDecoration(hintText: 'Ej. Reunión con equipo de diseño'),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Por favor ingresa un título';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Selector de Categoría
                        _buildFieldLabel('Categoría'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: CalendarTheme.allCategories.map((cat) {
                            final isCatSelected = _selectedCategory == cat;
                            final catColor = CalendarTheme.colorForCategory(cat);

                            return InkWell(
                              onTap: () => setState(() => _selectedCategory = cat),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isCatSelected
                                      ? catColor.withValues(alpha: 0.2)
                                      : CalendarTheme.mainBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isCatSelected ? catColor : CalendarTheme.border,
                                    width: isCatSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: catColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        color: isCatSelected
                                            ? CalendarTheme.textPrimary
                                            : CalendarTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: isCatSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Fecha y Horarios
                        _buildFieldLabel('Fecha'),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: CalendarTheme.mainBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: CalendarTheme.border, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 15, color: CalendarTheme.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    CalendarTheme.formatFullDateWithWeekday(
                                        _selectedDate),
                                    style: const TextStyle(
                                        color: CalendarTheme.textPrimary,
                                        fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Todo el día Switch
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Evento de todo el día',
                              style: TextStyle(color: CalendarTheme.textPrimary, fontSize: 13),
                            ),
                            Switch(
                              value: _isAllDay,
                              activeTrackColor:
                                  CalendarTheme.accent.withValues(alpha: 0.5),
                              activeThumbColor: CalendarTheme.accent,
                              onChanged: (val) =>
                                  setState(() => _isAllDay = val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Rango Horario
                        if (!_isAllDay)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Hora de inicio'),
                                    InkWell(
                                      onTap: () => _pickTime(isStart: true),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: CalendarTheme.mainBg,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                              color: CalendarTheme.border, width: 1),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time_rounded,
                                                size: 14, color: CalendarTheme.textSecondary),
                                            const SizedBox(width: 6),
                                            Text(
                                              _startTime.format(context),
                                              style: const TextStyle(
                                                  color: CalendarTheme.textPrimary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Hora de fin'),
                                    InkWell(
                                      onTap: () => _pickTime(isStart: false),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: CalendarTheme.mainBg,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                              color: CalendarTheme.border, width: 1),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time_rounded,
                                                size: 14, color: CalendarTheme.textSecondary),
                                            const SizedBox(width: 6),
                                            Text(
                                              _endTime.format(context),
                                              style: const TextStyle(
                                                  color: CalendarTheme.textPrimary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 14),

                        // Ubicación o enlace
                        _buildFieldLabel('Ubicación o enlace'),
                        TextFormField(
                          controller: _locationController,
                          style: const TextStyle(color: CalendarTheme.textPrimary, fontSize: 13),
                          decoration: _inputDecoration(hintText: 'Ej. Sala de reuniones o enlace Meet'),
                        ),
                        const SizedBox(height: 14),

                        // Descripción / Notas
                        _buildFieldLabel('Descripción / Notas'),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          style: const TextStyle(color: CalendarTheme.textPrimary, fontSize: 13),
                          decoration: _inputDecoration(hintText: 'Notas confidenciales sobre el evento...'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: CalendarTheme.borderSubtle),
                const SizedBox(height: 14),

                // ── Botones de Acción ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isEditing)
                      TextButton.icon(
                        onPressed: _isLoading ? null : _deleteEvent,
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: Color(0xFFEF4444)),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: CalendarTheme.textSecondary, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CalendarTheme.accent,
                            foregroundColor: const Color(0xFF111318),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  isEditing ? 'Guardar Cambios' : 'Crear Evento',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label,
        style: const TextStyle(
          color: CalendarTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: CalendarTheme.textDisabled, fontSize: 12),
      filled: true,
      fillColor: CalendarTheme.mainBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: CalendarTheme.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: CalendarTheme.accent, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
    );
  }
}
