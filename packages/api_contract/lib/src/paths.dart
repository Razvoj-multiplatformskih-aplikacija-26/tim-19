/// Putanje API-ja. Akcija nad zahtevom je pod-resurs zahteva (`POST /api/v1/requests/{id}/cancellation`);
/// server po ulozi iz prijave bira akciju iz domena (npr. otkazivanje klijenta ili moderatora).
abstract final class ApiPaths {
  static const health = '/health';

  static const sessions = '/api/v1/sessions';
  static const currentSession = '/api/v1/sessions/current';

  /// Katalog verifikovanih pružalaca; jedini deo API-ja dostupan bez prijave.
  static const providers = '/api/v1/providers';

  /// Klijenti sa imenima; samo za moderatora.
  static const clients = '/api/v1/clients';

  /// Zahtevi koje prijavljeni korisnik sme da vidi (klijent svoje, pružalac upućene njemu, moderator sve).
  static const requests = '/api/v1/requests';

  static String provider(String id) => '$providers/$id';

  static String request(String id) => '$requests/$id';

  /// Otkazivanje: klijent svoj poslat zahtev, moderator svaki nezavršen.
  static String cancellation(String id) => '${request(id)}/cancellation';

  /// Klijent potvrđuje isporuku.
  static String completion(String id) => '${request(id)}/completion';

  /// Klijent vraća isporučen zahtev na doradu.
  static String revision(String id) => '${request(id)}/revision';

  /// Pružalac prihvata poslat zahtev.
  static String acceptance(String id) => '${request(id)}/acceptance';

  /// Pružalac odbija poslat zahtev.
  static String rejection(String id) => '${request(id)}/rejection';

  /// Moderator zatvara isporučen zahtev kao završen.
  static String closure(String id) => '${request(id)}/closure';

  /// Moderator vraća isporučen zahtev u izradu.
  static String reopening(String id) => '${request(id)}/reopening';
}

/// Parametri upita za listu zahteva.
abstract final class ApiQuery {
  /// Filter po stanju, vrednost iz [RequestStatusDto].
  static const status = 'status';

  /// Najviše zapisa u odgovoru.
  static const limit = 'limit';

  /// Koliko zapisa preskočiti od početka.
  static const offset = 'offset';

  static const defaultLimit = 50;
  static const maxLimit = 200;
}

abstract final class ApiCookies {
  /// HttpOnly kolačić sa prijavom u pregledaču.
  static const session = 'soundconnect_session';
}
