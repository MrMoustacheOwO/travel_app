import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/participant.dart';
import '../models/spending_category.dart';
import '../models/trip.dart';
import '../providers/activities_provider.dart';
import '../providers/expenses_provider.dart';
import '../providers/participants_provider.dart';
import '../widgets/activity_tile.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/confirm_delete.dart';
import 'add_activity_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Set<SpendingCategory> _selectedCategories = {};
  bool _mainActivitiesOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivitiesProvider>().loadForTrip(widget.trip.id);
      context.read<ParticipantsProvider>().loadForTrip(widget.trip.id);
      context.read<ExpensesProvider>().loadForTrip(widget.trip.id);
    });
  }

  @override
  void didUpdateWidget(covariant TripDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id) {
      context.read<ActivitiesProvider>().loadForTrip(widget.trip.id);
      context.read<ParticipantsProvider>().loadForTrip(widget.trip.id);
      context.read<ExpensesProvider>().loadForTrip(widget.trip.id);
    }
  }

  bool _isOrganizer(List<Participant> participants) {
    if (participants.isEmpty) return true;
    return participants.first.role == TripParticipantRole.organizer;
  }

  @override
  Widget build(BuildContext context) {
    final activitiesProvider = context.watch<ActivitiesProvider>();
    final participants = context.watch<ParticipantsProvider>().participants;
    final isOrganizer = _isOrganizer(participants);
    final df = DateFormat('dd.MM.yyyy');
    final activities = activitiesProvider.activities
        .where((activity) =>
          (_selectedCategories.isEmpty ||
            _selectedCategories.contains(activity.category)) &&
          (!_mainActivitiesOnly || activity.isMain))
        .toList();

    return Scaffold(
      body: activitiesProvider.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${df.format(widget.trip.startDate)} — ${df.format(widget.trip.endDate)}',
                        ),
                      ),
                      Chip(
                        label: Text(widget.trip.status.label),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CategoryFilterButton(
                      selected: _selectedCategories,
                      mainOnly: _mainActivitiesOnly,
                      onMainOnlyChanged: (value) =>
                          setState(() => _mainActivitiesOnly = value),
                      onChanged: (value) =>
                          setState(() => _selectedCategories = value),
                    ),
                  ),
                ),
                Expanded(
                  child: activities.isEmpty
                      ? Center(
                          child: Text(
                            activitiesProvider.activities.isEmpty
                                ? 'Пока нет запланированных активностей.\nНажмите «+», чтобы добавить.'
                                : 'Активностей в выбранных категориях нет.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: activities.length,
                          itemBuilder: (context, index) {
                            final activity = activities[index];
                            return ActivityTile(
                              activity: activity,
                              participants: participants,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddActivityScreen(
                                      tripId: widget.trip.id,
                                      activity: activity,
                                      readOnly: !isOrganizer,
                                    ),
                                  ),
                                );
                              },
                              onDelete: isOrganizer
                                  ? () async {
                                      final ok = await confirmDelete(
                                        context,
                                        title: 'Удалить активность?',
                                        content:
                                            'Активность «${activity.name}» и связанный расход будут удалены.',
                                      );
                                      if (!ok || !context.mounted) return;
                                      await context
                                          .read<ActivitiesProvider>()
                                          .deleteActivity(activity.id);
                                      if (!context.mounted) return;
                                      await context
                                          .read<ExpensesProvider>()
                                          .loadForTrip(widget.trip.id);
                                    }
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: isOrganizer
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddActivityScreen(tripId: widget.trip.id),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
