import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final int participantCount;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const TripCard({
    super.key,
    required this.trip,
    required this.participantCount,
    required this.onTap,
    this.onEdit,
    required this.onDelete,
    this.onAccept,
    this.onDecline,
  });

  Color _statusColor() {
    switch (trip.status) {
      case TripStatus.planned:
        return Colors.blue.shade100;
      case TripStatus.active:
        return Colors.green.shade100;
      case TripStatus.completed:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        '${df.format(trip.startDate)} — ${df.format(trip.endDate)}'),
                    const SizedBox(height: 4),
                    Text('Участников: $participantCount'),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(trip.membershipStatus == 'invited'
                          ? 'Ожидает ответа'
                          : trip.status.label),
                      backgroundColor: trip.membershipStatus == 'invited'
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : _statusColor(),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    if (trip.membershipStatus == 'invited')
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: onAccept,
                            icon: const Icon(Icons.check),
                            label: const Text('Принять'),
                          ),
                          TextButton.icon(
                            onPressed: onDecline,
                            icon: const Icon(Icons.close),
                            label: const Text('Отказаться'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
