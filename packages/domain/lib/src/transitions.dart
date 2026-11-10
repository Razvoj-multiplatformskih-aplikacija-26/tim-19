import 'request_status.dart';
import 'user.dart';

/// Jedina funkcija koja kaže koji su prelazi dozvoljeni i kome.
///
/// Klijent otkazuje poslat zahtev, potvrđuje isporuku ili vraća isporučen zahtev na doradu.
/// Pružalac prihvata ili odbija poslat zahtev, počinje rad i isporučuje.
/// Moderator otkazuje svaki zahtev koji nije završen, odbijen ili otkazan, a isporučen zatvara kao završen
/// ili vraća u izradu.
bool canTransition(RequestStatus from, RequestStatus to, Role role) => switch ((role, from, to)) {
  (Role.client, RequestStatus.sent, RequestStatus.cancelled) => true,
  (Role.client, RequestStatus.delivered, RequestStatus.completed) => true,
  (Role.client, RequestStatus.delivered, RequestStatus.inProgress) => true,
  (Role.provider, RequestStatus.sent, RequestStatus.accepted) => true,
  (Role.provider, RequestStatus.sent, RequestStatus.rejected) => true,
  (Role.provider, RequestStatus.accepted, RequestStatus.inProgress) => true,
  (Role.provider, RequestStatus.inProgress, RequestStatus.delivered) => true,
  (Role.moderator, _, RequestStatus.cancelled) => !from.isFinal,
  (Role.moderator, RequestStatus.delivered, RequestStatus.completed) => true,
  (Role.moderator, RequestStatus.delivered, RequestStatus.inProgress) => true,
  _ => false,
};
