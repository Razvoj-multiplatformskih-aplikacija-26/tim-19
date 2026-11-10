import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

part 'new_request_event.dart';
part 'new_request_state.dart';

/// Forma za novi zahtev. Napomenu proverava pravilo iz domena pri svakom unosu.
final class NewRequestBloc extends Bloc<NewRequestEvent, NewRequestState> {
  NewRequestBloc({required this.requests, required this.provider, required this.user})
    : super(NewRequestState(service: provider.services.first)) {
    on<NoteChanged>((event, emit) {
      emit(
        state.copyWith(
          note: event.text,
          noteError: _noteError(event.text, attempted: state.attempted),
        ),
      );
    });
    on<ServiceChanged>((event, emit) => emit(state.copyWith(service: event.service)));
    on<SubmitNewRequest>(_onSubmit);
  }

  final RequestsRepository requests;
  final Provider provider;

  /// Prijavljeni klijent; zahtev se šalje u njegovo ime.
  final User user;

  /// Prazna napomena se prijavljuje tek posle prvog slanja, da forma ne počne crvena.
  static DomainError? _noteError(String text, {required bool attempted}) => switch (noteWithinLength(text)) {
    Failure(error: NoteEmpty()) when !attempted => null,
    Failure(:final error) => error,
    Success() => null,
  };

  Future<void> _onSubmit(SubmitNewRequest event, Emitter<NewRequestState> emit) async {
    if (state.status == NewRequestStatus.submitting) return;
    final noteError = _noteError(state.note, attempted: true);
    if (noteError != null) {
      emit(state.copyWith(attempted: true, noteError: noteError));
      return;
    }
    emit(state.copyWith(attempted: true, noteError: null, status: NewRequestStatus.submitting));
    final draft = NewRequest(
      clientId: user.asClient,
      providerId: provider.id,
      service: state.service,
      note: state.note,
    );
    try {
      switch (await requests.create(draft)) {
        case Success(:final value):
          emit(state.copyWith(status: NewRequestStatus.done, created: value));
        case Failure(:final error):
          emit(state.copyWith(status: NewRequestStatus.editing, submitError: error));
      }
    } on Exception catch (cause) {
      emit(state.copyWith(status: NewRequestStatus.editing, failure: cause));
    }
  }
}
