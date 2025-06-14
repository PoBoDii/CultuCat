import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:easy_localization/easy_localization.dart';

class TableBasicsExample extends StatefulWidget {
  final Function(DateTime)? onDateSelected;
  final DateTime? selectedDate;
  // Nuevo callback para cuando se quieren ver todos los eventos
  final VoidCallback? onViewAllEvents;
  // Nuevo callback para notificar cambios en el formato
  final Function(CalendarFormat)? onFormatChanged;
  // Formato inicial del calendario
  final CalendarFormat initialFormat;

  const TableBasicsExample({
    super.key,
    this.onDateSelected,
    this.selectedDate,
    this.onViewAllEvents,
    this.onFormatChanged,
    this.initialFormat = CalendarFormat.month,
  });

  @override
  State<TableBasicsExample> createState() => _TableBasicsExampleState();
}

class _TableBasicsExampleState extends State<TableBasicsExample> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  // Variable para controlar si se muestran todos los eventos
  bool _showAllEvents = false;

  @override
  void initState() {
    super.initState();
    _calendarFormat = widget.initialFormat;
    _focusedDay = widget.selectedDate ?? DateTime.now();
    _selectedDay = widget.selectedDate ?? DateTime.now();
  }

  @override
  void didUpdateWidget(TableBasicsExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != null &&
        (oldWidget.selectedDate == null ||
            !isSameDay(widget.selectedDate!, oldWidget.selectedDate!))) {
      setState(() {
        _selectedDay = widget.selectedDate;
        _focusedDay = widget.selectedDate!;
      });
    }

    // Actualizar el formato si cambia desde fuera
    if (widget.initialFormat != oldWidget.initialFormat) {
      setState(() {
        _calendarFormat = widget.initialFormat;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcular el tamaño ideal del calendario según el formato
    double rowHeight = _calendarFormat == CalendarFormat.month ? 40 : 45;

    return Column(
      mainAxisSize: MainAxisSize.min, // Usar el mínimo espacio necesario
      children: [
        // Calendar with adaptive height
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          // Habilitar el cambio de formato para adaptar el tamaño
          availableCalendarFormats:  {
            CalendarFormat.month: 'month'.tr(),
            CalendarFormat.twoWeeks: '2_weeks'.tr(),
            CalendarFormat.week: 'week'.tr(),
          },
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _showAllEvents = false; // Resetear la vista de todos los eventos
              });

              if (widget.onDateSelected != null) {
                widget.onDateSelected!(selectedDay);
              }
            }
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });

              // Notificar el cambio al padre
              if (widget.onFormatChanged != null) {
                widget.onFormatChanged!(format);
              }
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            // Reducir tamaño de título y botones para ahorrar espacio vertical
            titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            formatButtonTextStyle: TextStyle(fontSize: 12),
            headerPadding: EdgeInsets.symmetric(vertical: 4.0),
          ),
          // Ajustar altura de filas según el formato para optimizar espacio
          rowHeight: rowHeight,
          // Reducir padding para optimizar espacio vertical
          daysOfWeekHeight: 16.0,
          sixWeekMonthsEnforced: false,
        ),

        // Botón para ver todos los eventos - Con tamaño optimizado
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showAllEvents = !_showAllEvents;
              });

              if (widget.onViewAllEvents != null) {
                widget.onViewAllEvents!();
              }
            },
            icon: Icon(_showAllEvents ? Icons.calendar_today : Icons.calendar_view_month, size: 18),
            label: Text(
              _showAllEvents ? "see_day_cal".tr() : "see_all_cal".tr(),
              style: TextStyle(fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showAllEvents ? Colors.green : Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size(200, 32), // Tamaño mínimo más pequeño
            ),
          ),
        ),
      ],
    );
  }
}