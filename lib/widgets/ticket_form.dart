import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ticket_info.dart';

class TicketForm extends StatelessWidget {
  final TicketInfo ticket;
  final ValueChanged<TicketInfo> onChanged;
  final bool requiredFields;

  const TicketForm({
    super.key,
    required this.ticket,
    required this.onChanged,
    this.requiredFields = true,
  });

  Future<void> _pickDateTime(BuildContext context, {required bool isDeparture}) async {
    final current = isDeparture ? ticket.departureDate : ticket.arrivalDate;
    final initial = current ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final next = ticket.copy();
    if (isDeparture) {
      next.departureDate = value;
    } else {
      next.arrivalDate = value;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Данные билета',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TransportKind>(
          key: ValueKey(ticket.transportKind),
          initialValue: ticket.transportKind,
          decoration: const InputDecoration(
            labelText: 'Тип транспорта',
            border: OutlineInputBorder(),
          ),
          items: TransportKind.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            final next = ticket.copy()..transportKind = v;
            onChanged(next);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: ticket.ticketNumber,
          decoration: const InputDecoration(
            labelText: 'Номер билета',
            border: OutlineInputBorder(),
          ),
          validator: requiredFields
              ? (v) => (v == null || v.trim().isEmpty) ? 'Укажите номер билета' : null
              : null,
          onChanged: (v) {
            ticket.ticketNumber = v;
            onChanged(ticket);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: ticket.transportNumber,
          decoration: const InputDecoration(
            labelText: 'Номер транспорта (рейс, поезд, автобус)',
            border: OutlineInputBorder(),
          ),
          validator: requiredFields
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажите номер транспорта' : null
              : null,
          onChanged: (v) {
            ticket.transportNumber = v;
            onChanged(ticket);
          },
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _pickDateTime(context, isDeparture: true),
          icon: const Icon(Icons.flight_takeoff),
          label: Text(
            ticket.departureDate == null
                ? 'Дата убывания'
                : 'Убывание: ${df.format(ticket.departureDate!)}',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pickDateTime(context, isDeparture: false),
          icon: const Icon(Icons.flight_land),
          label: Text(
            ticket.arrivalDate == null
                ? 'Дата прибытия'
                : 'Прибытие: ${df.format(ticket.arrivalDate!)}',
          ),
        ),
      ],
    );
  }
}

class TicketDetailsText extends StatelessWidget {
  final TicketInfo ticket;

  const TicketDetailsText({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    if (!ticket.hasData) return const SizedBox.shrink();
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>[
      ticket.transportKind.label,
      if (ticket.ticketNumber.trim().isNotEmpty) '№ билета: ${ticket.ticketNumber}',
      if (ticket.transportNumber.trim().isNotEmpty)
        '№ транспорта: ${ticket.transportNumber}',
      if (ticket.departureDate != null) 'Убывание: ${df.format(ticket.departureDate!)}',
      if (ticket.arrivalDate != null) 'Прибытие: ${df.format(ticket.arrivalDate!)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        lines.join('\n'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
