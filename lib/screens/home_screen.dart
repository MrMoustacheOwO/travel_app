import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_sync_service.dart';
import '../models/trip.dart';
import '../providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/data_loading_widget.dart';
import '../widgets/sync_status_banner.dart';
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
  RealtimeChannel? _membershipChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripsProvider>().loadTrips();
      _membershipChannel = Supabase.instance.client
          .channel('home-trip-memberships')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trip_members',
            callback: (_) {
              if (mounted) {
                context.read<SupabaseSyncService>().requestSync();
              }
            },
          )
          .subscribe();
    });
  }

  @override
  void dispose() {
    unawaited(_membershipChannel?.unsubscribe());
    super.dispose();
  }

  Future<void> _respondToInvitation(Trip trip, {required bool accept}) async {
    final syncService = context.read<SupabaseSyncService>();
    final tripsProvider = context.read<TripsProvider>();
    final membershipId = trip.membershipId;
    if (membershipId == null) return;
    try {
      await syncService.respondToTripInvitation(
        tripId: trip.id,
        membershipId: membershipId,
        accept: accept,
      );
      if (!mounted) return;
      await tripsProvider.loadTrips();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось ответить на приглашение: $error')),
      );
    }
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
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: tripsProvider.loading
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
                          final isInvitation =
                              trip.membershipStatus == 'invited';
                          return TripCard(
                            trip: trip,
                            participantCount:
                                tripsProvider.participantCountFor(trip.id),
                            onTap: isInvitation
                                ? null
                                : () => widget.onTripSelected(trip),
                            onAccept: isInvitation && trip.membershipId != null
                                ? () => _respondToInvitation(
                                      trip,
                                      accept: true,
                                    )
                                : null,
                            onDecline: isInvitation && trip.membershipId != null
                                ? () => _respondToInvitation(
                                      trip,
                                      accept: false,
                                    )
                                : null,
                            onEdit: canManage
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddTripScreen(trip: trip),
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
          ),
        ],
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
