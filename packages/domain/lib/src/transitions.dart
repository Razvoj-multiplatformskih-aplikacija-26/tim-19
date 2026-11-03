import 'actor.dart';
import 'request_status.dart';

/// Jedina funkcija koja kaže koji su prelazi dozvoljeni i kome.
///
/// Klijent otkazuje poslat zahtev, potvrđuje isporuku ili vraća isporučen zahtev na doradu.
/// Pružalac prihvata ili odbija poslat zahtev, počinje rad i isporučuje.
/// Moderator otkazuje svaki zahtev koji nije završen, odbijen ili otkazan, a isporučen zatvara kao završen
/// ili vraća u izradu.
bool canTransition(RequestStatus from, RequestStatus to, Actor actor) => switch ((actor, from, to)) {
  (Actor.client, RequestStatus.sent, RequestStatus.cancelled) => true,
  (Actor.client, RequestStatus.delivered, RequestStatus.completed) => true,
  (Actor.client, RequestStatus.delivered, RequestStatus.inProgress) => true,
  (Actor.provider, RequestStatus.sent, RequestStatus.accepted) => true,
  (Actor.provider, RequestStatus.sent, RequestStatus.rejected) => true,
  (Actor.provider, RequestStatus.accepted, RequestStatus.inProgress) => true,
  (Actor.provider, RequestStatus.inProgress, RequestStatus.delivered) => true,
  (Actor.moderator, _, RequestStatus.cancelled) => !from.isFinal,
  (Actor.moderator, RequestStatus.delivered, RequestStatus.completed) => true,
  (Actor.moderator, RequestStatus.delivered, RequestStatus.inProgress) => true,
  _ => false,
};
