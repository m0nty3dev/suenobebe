import '../../data/events_repository.dart';

class DeleteEvent {
  const DeleteEvent(this._repository);
  final EventsRepository _repository;

  Future<void> call(String babyId, String eventId) async {
    await _repository.deleteEvent(babyId, eventId);
  }
}
