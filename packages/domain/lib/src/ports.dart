import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'actions.dart';
import 'identifiers.dart';
import 'model.dart';
import 'request_status.dart';
import 'result.dart';
import 'user.dart';

// Portovi ka podacima. Klijenti ih dobijaju kroz konstruktor; implementacija je HTTP (api_client) ili lažna
// u memoriji (testovi, demo). Ekrani i Bloc-ovi ne znaju koja je.

/// Deo liste zahteva: [items] počev od [offset], od ukupno [total].
@immutable
final class RequestPage {
  const RequestPage({required this.items, required this.total, this.offset = 0});

  final List<CollaborationRequest> items;
  final int total;
  final int offset;

  bool get hasMore => offset + items.length < total;

  @override
  bool operator ==(Object other) =>
      other is RequestPage &&
      const ListEquality<CollaborationRequest>().equals(other.items, items) &&
      other.total == total &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(const ListEquality<CollaborationRequest>().hash(items), total, offset);
}

abstract interface class RequestsRepository {
  /// Zahtevi koje prijavljeni korisnik sme da vidi (klijent svoje, pružalac upućene njemu, moderator sve),
  /// najnoviji prvi, po stranama.
  Future<RequestPage> requests({RequestStatus? status, int offset = 0, int limit = 50});

  Future<CollaborationRequest?> getById(RequestId id);

  /// Novi zahtev u ime prijavljenog klijenta.
  Future<Result<CollaborationRequest>> create(NewRequest draft);

  /// Akcija nad zahtevom. [from] je stanje koje je korisnik video; ako se u međuvremenu promenilo,
  /// odgovor je [StaleRequest] umesto izmene za koju korisnik nije znao.
  Future<Result<CollaborationRequest>> apply(RequestAction action, RequestId id, {required RequestStatus from});
}

abstract interface class ProvidersRepository {
  /// Pružaoci koje korisnik vidi, sa slobodnim mestima. Slobodna mesta računa server nad zahtevima svih
  /// klijenata, jer klijent tuđe zahteve ne vidi.
  Future<List<CatalogEntry>> catalog();

  Future<CatalogEntry?> entry(ProviderId id);
}

abstract interface class ClientsRepository {
  Future<List<Client>> allClients();
}

/// Prijava. Prijavu (token) čuva implementacija iza ovog porta; lozinka se nigde ne čuva.
abstract interface class SessionRepository {
  /// Uspeh nosi korisnika; neuspeh je [InvalidCredentials] ili [WrongApp].
  Future<Result<User>> signIn({required String username, required String password, required ClientApp app});

  /// Važeća sačuvana prijava (posle ponovnog pokretanja ili osvežavanja stranice), ili `null`.
  Future<User?> current();

  Future<void> signOut();

  /// Javlja kada server kaže da je prijava istekla, iz bilo kog poziva.
  Stream<void> get expirations;
}

/// Zašto port nije mogao da odgovori; nije greška pravila, pa poruku bira klijent po vrsti.
enum RepositoryFailure {
  /// Nema mreže, server ne radi ili ne odgovara na vreme.
  unreachable,

  /// Prijava je istekla ili ne postoji.
  sessionExpired,

  /// Server je odgovorio greškom ili odgovorom koji klijent ne razume.
  serverError,
}

/// Port nije mogao da odgovori (mreža, server); nije greška pravila.
final class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.failure = RepositoryFailure.unreachable, this.cause});

  final String message;
  final RepositoryFailure failure;
  final Object? cause;

  @override
  String toString() => 'RepositoryException(${failure.name}): $message';
}
