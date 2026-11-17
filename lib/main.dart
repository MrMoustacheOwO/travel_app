import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'data/db/database_helper.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/local_trip_repository.dart';
import 'data/repositories/participant_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/supabase_auth_repository.dart';
import 'data/repositories/trip_repository.dart';
import 'data/supabase_sync_service.dart';
import 'providers/activities_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/expenses_provider.dart';
import 'providers/participants_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/trips_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'widgets/data_loading_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  final supabase = Supabase.instance.client;
  final AuthRepository authRepository = SupabaseAuthRepository(supabase);
  final syncService = SupabaseSyncService(client: supabase);
  final onLocalChange = syncService.requestSync;
  runApp(
    TravelExpensesApp(
      authRepository: authRepository,
      syncService: syncService,
      tripRepository: LocalTripRepository(
        authRepository: authRepository,
        onChanged: onLocalChange,
      ),
      participantRepository:
          LocalParticipantRepository(onChanged: onLocalChange),
      activityRepository: LocalActivityRepository(onChanged: onLocalChange),
      expenseRepository: LocalExpenseRepository(onChanged: onLocalChange),
      profileRepository: LocalProfileRepository(
        authRepository: authRepository,
        onChanged: onLocalChange,
      ),
    ),
  );
}

class TravelExpensesApp extends StatelessWidget {
  const TravelExpensesApp({
    required this.authRepository,
    required this.syncService,
    required this.tripRepository,
    required this.participantRepository,
    required this.activityRepository,
    required this.expenseRepository,
    required this.profileRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final SupabaseSyncService syncService;
  final TripRepository tripRepository;
  final ParticipantRepository participantRepository;
  final ActivityRepository activityRepository;
  final ExpenseRepository expenseRepository;
  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: syncService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authRepository,
            onAuthenticated: syncService.requestSync,
          )..loadCurrentUser(),
        ),
        ChangeNotifierProvider(
          create: (_) => TripsProvider(
            tripRepository,
            participantRepository: participantRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ParticipantsProvider(participantRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ActivitiesProvider(activityRepository),
        ),
        ChangeNotifierProvider(
            create: (_) => ExpensesProvider(expenseRepository)),
        ChangeNotifierProvider(
            create: (_) => ProfileProvider(profileRepository)),
      ],
      child: MaterialApp(
        title: 'Учет поездок',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) return const Scaffold(body: DataLoadingWidget());
    if (auth.isAuthenticated) return const MainShell();
    return const AuthScreen();
  }
}
