import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'passwords.dart';
import 'store.dart';

/// Demo nalozi: prijava → korisnik. Lozinka svih je `DEMO_PASSWORD` iz `.env`; u bazi je samo Argon2id heš.
const demoLogins = {'klijent1': 'c-sava', 'klijent2': 'c-mila', 'pruzalac1': 'p-marko', 'moderator1': 'm-kosta'};

const _moderator = User(id: UserId('m-kosta'), name: 'Kosta Baštić', role: Role.moderator);

const _clients = [
  User(id: UserId('c-sava'), name: 'Sava Radošević', role: Role.client),
  User(id: UserId('c-mila'), name: 'Mila Jovanović', role: Role.client),
  User(id: UserId('c-luka'), name: 'Luka Ilić', role: Role.client),
  User(id: UserId('c-tara'), name: 'Tara Nikolić', role: Role.client),
  User(id: UserId('c-vuk'), name: 'Vuk Stojanović', role: Role.client),
  User(id: UserId('c-iva'), name: 'Iva Marković', role: Role.client),
];

/// Pružaoci; Marko ima i nalog (`pruzalac1`), a njegov profil ima isti identifikator kao nalog.
const _providers = [
  Provider(
    id: ProviderId('p-marko'),
    name: 'Marko „Mix“ Petrović',
    verified: true,
    genres: [Genre.hipHop, Genre.rnb],
    services: [ServiceType.mixing, ServiceType.mastering],
    priceFrom: 80,
    capacity: 3,
    bio: 'Audio inženjer, 10 godina miksa za hip-hop i R&B izdanja.',
  ),
  Provider(
    id: ProviderId('p-jelena'),
    name: 'Jelena Vokal',
    verified: true,
    genres: [Genre.pop, Genre.rnb, Genre.jazz],
    services: [ServiceType.vocals],
    priceFrom: 60,
    capacity: 3,
    bio: 'Vokalistkinja i autorka toplajna, snima u sopstvenom studiju.',
  ),
  Provider(
    id: ProviderId('p-nikola'),
    name: 'Nikola Beats',
    verified: true,
    genres: [Genre.hipHop, Genre.electronic],
    services: [ServiceType.beat, ServiceType.mixing],
    priceFrom: 50,
    capacity: 4,
    bio: 'Producent bitova za trep i elektronsku muziku.',
  ),
  Provider(
    id: ProviderId('p-studio'),
    name: 'Studio Dorćol',
    verified: true,
    genres: [Genre.rock, Genre.pop, Genre.folk],
    services: [ServiceType.mixing, ServiceType.mastering, ServiceType.vocals],
    priceFrom: 120,
    capacity: 3,
    bio: 'Studio sa live sobom; miks i mastering za bendove.',
  ),
  Provider(
    id: ProviderId('p-ana'),
    name: 'Ana Master',
    verified: true,
    genres: [Genre.electronic, Genre.pop],
    services: [ServiceType.mastering],
    priceFrom: 40,
    capacity: 3,
    bio: 'Mastering za striming servise i vinil.',
  ),
  Provider(
    id: ProviderId('p-djole'),
    name: 'Đorđe Jazz Lab',
    verified: true,
    genres: [Genre.jazz],
    services: [ServiceType.mixing],
    priceFrom: 90,
    capacity: 1,
    bio: 'Akustični miks za džez i kamernu muziku.',
  ),
  Provider(
    id: ProviderId('p-novi'),
    name: 'Novi Producent',
    verified: false,
    genres: [Genre.pop],
    services: [ServiceType.beat],
    priceFrom: 30,
    capacity: 3,
  ),
];

/// Zahtevi svih klijenata, svako stanje bar jednom. Jelena ima tačno jedno slobodno mesto (trka na odbrani),
/// Marko i Đorđe nemaju slobodnih mesta.
const _requests = <(String, String, ServiceType, RequestStatus, String, int)>[
  ('c-sava', 'p-marko', ServiceType.mixing, RequestStatus.sent, 'Miks singla „Noćna vožnja“.', 0),
  ('c-sava', 'p-ana', ServiceType.mastering, RequestStatus.accepted, 'Mastering EP-a za Spotify.', 0),
  ('c-sava', 'p-nikola', ServiceType.beat, RequestStatus.inProgress, 'Trep bit, 140 BPM.', 0),
  ('c-sava', 'p-marko', ServiceType.mastering, RequestStatus.delivered, 'Mastering singla, -9 LUFS.', 0),
  ('c-sava', 'p-nikola', ServiceType.mixing, RequestStatus.delivered, 'Miks bita sa vokalom.', 2),
  ('c-mila', 'p-marko', ServiceType.mixing, RequestStatus.inProgress, 'Miks remiksa.', 0),
  ('c-mila', 'p-jelena', ServiceType.vocals, RequestStatus.sent, 'Prateći vokali za refren.', 0),
  ('c-mila', 'p-studio', ServiceType.mastering, RequestStatus.completed, 'Mastering albuma.', 1),
  ('c-luka', 'p-djole', ServiceType.mixing, RequestStatus.accepted, 'Džez kvartet, miks.', 0),
  ('c-luka', 'p-jelena', ServiceType.vocals, RequestStatus.delivered, 'Vokal za reklamu, spor oko tona.', 1),
  ('c-luka', 'p-studio', ServiceType.mixing, RequestStatus.rejected, 'Miks demo snimka.', 0),
  ('c-tara', 'p-ana', ServiceType.mastering, RequestStatus.sent, 'Mastering za vinil.', 0),
  ('c-tara', 'p-nikola', ServiceType.beat, RequestStatus.cancelled, 'Bit za reklamu.', 0),
  ('c-tara', 'p-studio', ServiceType.vocals, RequestStatus.inProgress, 'Snimanje vokala u studiju.', 0),
  ('c-vuk', 'p-marko', ServiceType.mastering, RequestStatus.completed, 'Mastering singla.', 0),
  ('c-vuk', 'p-studio', ServiceType.mixing, RequestStatus.delivered, 'Miks live snimka, 12 kanala.', 0),
  ('c-vuk', 'p-jelena', ServiceType.vocals, RequestStatus.cancelled, 'Glavni vokal.', 0),
  ('c-iva', 'p-nikola', ServiceType.mixing, RequestStatus.accepted, 'Miks elektronske numere.', 0),
  ('c-iva', 'p-ana', ServiceType.mastering, RequestStatus.rejected, 'Mastering 10 pesama za sutra.', 0),
  ('c-iva', 'p-jelena', ServiceType.vocals, RequestStatus.completed, 'Toplajn za pop pesmu.', 2),
];

/// Puni praznu bazu početnim podacima, u jednoj transakciji. Nad bazom koja već ima podatke ne radi ništa.
Future<bool> seedDemoData(Pool<void> database, {required DateTime now, required String? demoPassword}) async {
  if (!await SoundStore(database).isEmpty()) return false;
  if (demoPassword == null || demoPassword.isEmpty) {
    throw StateError('DEMO_PASSWORD nije postavljen. Kopirajte .env.example u .env.');
  }
  final hash = await hashPassword(demoPassword);
  final logins = {for (final MapEntry(:key, :value) in demoLogins.entries) value: key};
  await database.runTx((session) async {
    final store = SoundStore(session);
    final markoProfile = _providers.first;
    final marko = User(id: UserId(markoProfile.id.value), name: markoProfile.name, role: Role.provider);
    for (final user in [..._clients, marko, _moderator]) {
      final login = logins[user.id.value];
      await store.insertUser(user, login: login, passwordHash: login == null ? null : hash);
    }
    for (final provider in _providers) {
      await store.insertProvider(provider);
    }
    for (final (i, (client, provider, service, status, note, revisions)) in _requests.indexed) {
      await store.insertRequest(
        CollaborationRequest(
          id: RequestId('r-${i + 1}'),
          clientId: ClientId(client),
          providerId: ProviderId(provider),
          service: service,
          note: note,
          status: status,
          createdAt: now.subtract(Duration(hours: 7 * i + 1)),
          revisions: revisions,
        ),
      );
    }
    await store.continueRequestNumbersAfter(_requests.length);
  });
  return true;
}
