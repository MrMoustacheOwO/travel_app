import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/data_loading_widget.dart';
import '../widgets/trip_card.dart';
import 'add_trip_screen.dart';
import 'profile_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(Trip trip) onTripSelected;

  const HomeScreen({super.key, required this.onTripSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripsProvider>().loadTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripsProvider = context.watch<TripsProvider>();
    final userId = context.watch<AuthProvider>().currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
            );
          },
        ),
        title: const Text('Мои поездки'),
      ),
      body: tripsProvider.loading
          ? DataLoadingWidget(
              onRetry: () => context.read<TripsProvider>().loadTrips(),
            )
          : tripsProvider.trips.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Пока нет ни одной поездки.\nНажмите «+», чтобы добавить первую.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: tripsProvider.trips.length,
                  itemBuilder: (context, index) {
                    final trip = tripsProvider.trips[index];
                    final canManage =
                        (trip.organizerId ?? trip.userId) == userId;
                    return TripCard(
                      trip: trip,
                      participantCount:
                          tripsProvider.participantCountFor(trip.id),
                      onTap: () => widget.onTripSelected(trip),
                      onEdit: canManage
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AddTripScreen(trip: trip),
                                ),
                              );
                            }
                          : null,
                      onDelete: canManage
                          ? () async {
                              final ok = await confirmDelete(
                                context,
                                title: 'Удалить поездку?',
                                content:
                                    'Поездка «${trip.name}» и все данные по ней будут удалены.',
                              );
                              if (!ok || !context.mounted) return;
                              await context
                                  .read<TripsProvider>()
                                  .deleteTrip(trip.id);
                            }
                          : null,
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final trip = await Navigator.of(context).push<Trip>(
            MaterialPageRoute(builder: (_) => const AddTripScreen()),
          );
          if (trip != null) widget.onTripSelected(trip);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
