import '../../models/trip.dart';

/// Контракт репозитория поездок.
///
/// Сейчас в приложении используется [LocalTripRepository] (SQLite).
/// Когда появится сервер, нужно будет просто создать, например,
/// `ApiTripRepository implements TripRepository`, который вместо
/// SQL-запросов будет ходить в REST API, и подменить реализацию
/// в месте создания провайдера (main.dart) — остальной код менять
/// не придётся.
abstract class TripRepository {
  Future<List<Trip>> getAllTrips();
  Future<Trip?> getTripById(String id);
  Future<void> createTrip(Trip trip);
  Future<void> updateTrip(Trip trip);
  Future<void> deleteTrip(String id);
}
