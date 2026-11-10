import 'model.dart';
import 'user.dart';

/// Jedino mesto za prava: ko sme u koju aplikaciju, koji zapis vidi i koju akciju sme da pokrene.
/// Koriste ga akcije iz domena, Bloc-ovi i server.
abstract final class AccessPolicy {
  /// Mobilnu aplikaciju koriste klijent i pružalac, backoffice samo moderator.
  static bool canSignIn(User user, ClientApp app) => switch (app) {
    ClientApp.mobile => user.role == Role.client || user.role == Role.provider,
    ClientApp.backoffice => user.role == Role.moderator,
  };

  /// Zahtev je klijentov ako ga je on poslao.
  static bool isOwner(User user, CollaborationRequest request) =>
      user.role == Role.client && request.clientId == user.asClient;

  /// Zahtev je upućen pružaocu ako je on izabran u zahtevu.
  static bool isAddressee(User user, CollaborationRequest request) =>
      user.role == Role.provider && request.providerId == user.asProvider;

  /// Klijent vidi svoje zahteve, pružalac zahteve upućene njemu, moderator sve.
  static bool canView(User user, CollaborationRequest request) =>
      user.role == Role.moderator || isOwner(user, request) || isAddressee(user, request);

  /// Pregled svih zahteva (tabela u backoffice-u).
  static bool canViewAll(User user) => user.role == Role.moderator;

  /// Zahtev šalje samo klijent, i to u svoje ime.
  static bool canCreateRequest(User user, NewRequest draft) =>
      user.role == Role.client && draft.clientId == user.asClient;

  /// Otkazivanje, potvrda isporuke i revizija: samo klijent, samo nad svojim zahtevom.
  static bool canActAsClient(User user, CollaborationRequest request) => isOwner(user, request);

  /// Prihvatanje i odbijanje: samo pružalac, samo nad zahtevom upućenim njemu.
  static bool canActAsProvider(User user, CollaborationRequest request) => isAddressee(user, request);

  /// Otkazivanje tuđeg zahteva, zatvaranje i vraćanje u izradu: samo moderator.
  static bool canModerate(User user) => user.role == Role.moderator;
}
