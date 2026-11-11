import 'package:domain/domain.dart';

import 'labels.dart';

/// Poruka na srpskom za svaku grešku pravila. Switch je iscrpan: nova greška u domenu ne prolazi
/// analizu dok ne dobije poruku.
String domainErrorMessage(DomainError error) => switch (error) {
  InvalidTransition(:final from, :final to) => 'Zahtev ne može da pređe iz stanja „${from.label}“ u „${to.label}“.',
  CancelNotAllowed() => 'Zahtev može da se otkaže samo dok ga pružalac nije prihvatio.',
  RevisionLimitReached(:final max) => 'Iskorišćene su sve revizije ($max).',
  NoFreeSlots() => 'Pružalac trenutno nema slobodnih mesta.',
  NoteTooLong(:final length, :final max) => 'Napomena je predugačka: $length od najviše $max znakova.',
  NoteEmpty() => 'Opišite šta vam treba.',
  ProviderNotListed() => 'Pružalac još nije verifikovan.',
  ServiceNotOffered(:final service) => 'Pružalac ne nudi uslugu „${service.label}“.',
  RequestClosed(:final status) => 'Zahtev je u stanju „${status.label}“ i više se ne menja.',
  NotDelivered() => 'Akcija je moguća samo za isporučen zahtev.',
  NotFound() => 'Zahtev nije pronađen.',
  NotAllowed() => 'Nemate pravo na ovu akciju.',
  WrongApp(app: ClientApp.backoffice) => 'Backoffice je za moderatore. Klijenti i pružaoci koriste mobilnu aplikaciju.',
  WrongApp(app: ClientApp.mobile) => 'Mobilna aplikacija je za klijente i pružaoce. Moderatori koriste backoffice.',
  StaleRequest(:final current) => 'Zahtev je u međuvremenu promenjen; sada je u stanju „${current.label}“.',
  ServerRejected() => 'Akcija trenutno nije moguća. Osvežite ekran i pokušajte ponovo.',
  InvalidCredentials() => 'Pogrešno korisničko ime ili lozinka.',
};

String failureMessage(Object cause) => switch (cause) {
  RepositoryException(failure: RepositoryFailure.unreachable) =>
    'Server nije dostupan. Proverite mrežu i pokušajte ponovo.',
  RepositoryException(failure: RepositoryFailure.sessionExpired) => sessionExpiredMessage,
  RepositoryException(failure: RepositoryFailure.serverError) =>
    'Server trenutno ne odgovara ispravno. Pokušajte ponovo malo kasnije.',
  _ => 'Došlo je do neočekivane greške.',
};

/// Korisnik je poslao formu za prijavu bez korisničkog imena ili lozinke.
const signInIncompleteMessage = 'Unesite korisničko ime i lozinku.';

/// Prijava je istekla posle vremena iz podešavanja servera.
const sessionExpiredMessage = 'Prijava je istekla. Prijavite se ponovo.';

/// Potvrda uspešne akcije nad zahtevom.
String actionDoneMessage(RequestAction action) => switch (action) {
  RequestAction.cancel => 'Zahtev je otkazan.',
  RequestAction.complete => 'Isporuka je potvrđena.',
  RequestAction.revise => 'Zahtev je vraćen na doradu.',
  RequestAction.accept => 'Zahtev je prihvaćen.',
  RequestAction.reject => 'Zahtev je odbijen.',
  RequestAction.close => 'Zahtev je zatvoren kao završen.',
  RequestAction.reopen => 'Zahtev je vraćen u izradu.',
};
