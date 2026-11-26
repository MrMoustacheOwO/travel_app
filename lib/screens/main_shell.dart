import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel_expenses_app/screens/profile_settings_screen.dart';

import '../models/trip.dart';
import '../data/supabase_sync_service.dart';
import '../providers/activities_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/expenses_provider.dart';
import '../providers/participants_provider.dart';
import '../providers/trips_provider.dart';
import '../widgets/sync_status_banner.dart';
import 'add_trip_screen.dart';
import 'expenses_screen.dart';
import 'home_screen.dart';
import 'participants_screen.dart';
import 'trip_detail_screen.dart';

/// Подвал (нижняя навигация) для основных экранов:
/// Главная страница, Поездка, Расходы, Участники.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  String? _selectedTripId;
  bool _syncWasRunning = false;

  void _selectTrip(Trip trip) {
    setState(() {
      _selectedTripId = trip.id;
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SupabaseSyncService>();
    if (sync.syncing) {
      _syncWasRunning = true;
    } else if (_syncWasRunning) {
      _syncWasRunning = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.read<AuthProvider>().isAuthenticated) return;
        context.read<TripsProvider>().loadTrips();
        final tripId = _selectedTripId;
        if (tripId != null) {
          context.read<ParticipantsProvider>().loadForTrip(tripId);
          context.read<ActivitiesProvider>().loadForTrip(tripId);
          context.read<ExpensesProvider>().loadForTrip(tripId);
        }
      });
    }

    final tripsProvider = context.watch<TripsProvider>();
    final selectedTrip = _selectedTripId == null
        ? null
        : tripsProvider.tripById(_selectedTripId!);
    final isTripOrganizer = selectedTrip != null &&
        (selectedTrip.organizerId ?? selectedTrip.userId) ==
            context.watch<AuthProvider>().currentUser?.id;

    final titles = ['Мои поездки', 'Поездка', 'Расходы', 'Участники'];

    Widget body;
    switch (_selectedIndex) {
      case 0:
        body = HomeScreen(onTripSelected: _selectTrip);
        break;
      case 1:
        body = selectedTrip == null
            ? const _NoTripSelected()
            : TripDetailScreen(trip: selectedTrip);
        break;
      case 2:
        body = selectedTrip == null
            ? const _NoTripSelected()
            : ExpensesScreen(trip: selectedTrip);
        break;
      case 3:
        body = selectedTrip == null
            ? const _NoTripSelected()
            : ParticipantsScreen(trip: selectedTrip);
        break;
      default:
        body = HomeScreen(onTripSelected: _selectTrip);
    }

    final appBar = _selectedIndex == 0
        ? null
        : AppBar(
            leading: IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProfileSettingsScreen()),
                );
              },
            ),
            title: Text(selectedTrip != null
                ? '${titles[_selectedIndex]} · ${selectedTrip.name}'
                : titles[_selectedIndex]),
            centerTitle: true,
            actions: [
              if (selectedTrip != null &&
                  _selectedIndex == 1 &&
                  isTripOrganizer)
                IconButton(
                  tooltip: 'Редактировать поездку',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddTripScreen(trip: selectedTrip),
                      ),
                    );
                  },
                ),
            ],
          );

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          if (_selectedIndex != 0) const SyncStatusBanner(),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Главная'),
          NavigationDestination(
              icon: Icon(Icons.flight_takeoff), label: 'Поездка'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Расходы'),
          NavigationDestination(
              icon: Icon(Icons.group_outlined), label: 'Участники'),
        ],
      ),
    );
  }
}

class _NoTripSelected extends StatelessWidget {
  const _NoTripSelected();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Сначала выберите поездку на главной странице.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
