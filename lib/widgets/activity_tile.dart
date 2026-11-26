import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../widgets/ticket_form.dart';

class ActivityTile extends StatelessWidget {
  final TripActivity activity;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ActivityTile({
    super.key,
    required this.activity,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: activity.isMain ? colorScheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: activity.isMain
                    ? colorScheme.primary
                    : colorScheme.secondaryContainer,
                foregroundColor: activity.isMain
                    ? colorScheme.onPrimary
                    : colorScheme.onSecondaryContainer,
                child: Text(activity.isMain
                    ? '\u2605'
                    : activity.category.label.substring(0, 1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (activity.isMain)
                      Text('Главная активность',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          )),
                    Text(
                      '${df.format(activity.dateTime)}\n'
                      '${activity.isTickets ? activity.ticket.transportKind.label : activity.category.label}'
                      '${activity.location.isNotEmpty ? ' · ${activity.location}' : ''}',
                    ),
                    if (activity.isTickets)
                      TicketDetailsText(ticket: activity.ticket),
                    Text(
                      '${activity.cost.toStringAsFixed(0)} ₽',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
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
