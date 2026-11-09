import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db/database_helper.dart';
import 'data/repositories/activity_repository.dart';
import 'config/backend_config.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/local_trip_repository.dart';
import 'data/repositories/participant_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/trip_repository.dart';
import 'providers/activities_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/expenses_provider.dart';
import 'providers/participants_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/trips_provider.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendConfig.initialize();
  await DatabaseHelper.instance.database;
  runApp(const TravelExpensesApp());
}

class TravelExpensesApp extends StatelessWidget {
  const TravelExpensesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final TripRepository tripRepository = LocalTripRepository();
    final ParticipantRepository participantRepository = LocalParticipantRepository();
    final ActivityRepository activityRepository = LocalActivityRepository();
    final ExpenseRepository expenseRepository = LocalExpenseRepository();
    final ProfileRepository profileRepository = LocalProfileRepository();
    final AuthRepository authRepository = ApiAuthRepository();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepository)..loadCurrentUser()),
        ChangeNotifierProvider(create: (_) => TripsProvider(tripRepository)),
        ChangeNotifierProvider(create: (_) => ParticipantsProvider(participantRepository)),
        ChangeNotifierProvider(create: (_) => ActivitiesProvider(activityRepository)),
        ChangeNotifierProvider(create: (_) => ExpensesProvider(expenseRepository)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(profileRepository)),
      ],
      child: MaterialApp(
        title: 'Учёт поездок',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const MainShell(),
      ),
    );
  }
}
