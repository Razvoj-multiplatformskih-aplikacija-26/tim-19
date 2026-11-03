import 'catalog.dart';
import 'errors.dart';
import 'model.dart';
import 'request_status.dart';
import 'result.dart';

/// Koliko puta klijent najviše vraća isporučen zahtev na doradu.
const maxRevisions = 2;

/// Najveća dužina napomene u zahtevu, u znakovima.
const maxNoteLength = 500;

/// Broj slobodnih mesta novog pružaoca.
const defaultCapacity = 3;

const Result<void> _ok = Success(null);

/// Klijent može da otkaže zahtev samo dok ga pružalac nije prihvatio.
Result<void> canCancelByClient(CollaborationRequest request) =>
    request.status == RequestStatus.sent ? _ok : Failure(CancelNotAllowed(request.status));

/// Zahtev ima najviše [maxRevisions] revizija.
Result<void> withinRevisionLimit(CollaborationRequest request) =>
    request.revisions < maxRevisions ? _ok : const Failure(RevisionLimitReached(max: maxRevisions));

/// Napomena nije prazna i nije duža od [maxNoteLength]; uspeh nosi očišćen tekst.
Result<String> noteWithinLength(String text) {
  final note = text.trim();
  if (note.isEmpty) return const Failure(NoteEmpty());
  if (note.length > maxNoteLength) return Failure(NoteTooLong(note.length, max: maxNoteLength));
  return Success(note);
}

/// Koliko mesta je pružaocu ostalo, računato nad zahtevima svih klijenata.
int freeSlots(Provider provider, Iterable<CollaborationRequest> requests) {
  final taken = requests.where((r) => r.providerId == provider.id && r.status.occupiesSlot).length;
  return taken >= provider.capacity ? 0 : provider.capacity - taken;
}

/// Pružalac ima bar jedno slobodno mesto; uspeh nosi broj slobodnih mesta.
///
/// Zavisi od zahteva drugih klijenata, pa konačno odlučuje server.
Result<int> providerHasCapacity(Provider provider, Iterable<CollaborationRequest> requests) {
  final free = freeSlots(provider, requests);
  return free > 0 ? Success(free) : Failure(NoFreeSlots(capacity: provider.capacity));
}

/// Pružalac se prikazuje u katalogu tek kada ga moderator verifikuje.
bool isListedInCatalog(Provider provider) => provider.verified;

/// Katalog: samo verifikovani pružaoci, po izboru filtrirani po žanru i usluzi.
List<Provider> catalog(Iterable<Provider> providers, {Genre? genre, ServiceType? service}) => [
  for (final p in providers)
    if (isListedInCatalog(p) &&
        (genre == null || p.genres.contains(genre)) &&
        (service == null || p.services.contains(service)))
      p,
];

/// Moderator otkazuje svaki zahtev koji nije završen, odbijen ili otkazan.
Result<void> moderatorCanCancel(CollaborationRequest request) =>
    request.status.isFinal ? Failure(RequestClosed(request.status)) : _ok;

/// Moderator zatvara kao završen samo isporučen zahtev.
Result<void> moderatorCanClose(CollaborationRequest request) =>
    request.status == RequestStatus.delivered ? _ok : Failure(NotDelivered(request.status));

/// Moderator vraća u izradu samo isporučen zahtev; to je rešavanje spora i ne troši reviziju klijenta.
Result<void> moderatorCanReopen(CollaborationRequest request) =>
    request.status == RequestStatus.delivered ? _ok : Failure(NotDelivered(request.status));
