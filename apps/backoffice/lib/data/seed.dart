import 'package:domain/domain.dart';

/// Prijavljeni moderator dok prijava ne stigne u KT2.
const moderator = User(id: UserId('m-kosta'), name: 'Kosta Baštić', role: Role.moderator);

const seedClients = [
  Client(id: ClientId('c-sava'), name: 'Sava Radošević'),
  Client(id: ClientId('c-mila'), name: 'Mila Jovanović'),
  Client(id: ClientId('c-luka'), name: 'Luka Ilić'),
  Client(id: ClientId('c-tara'), name: 'Tara Nikolić'),
  Client(id: ClientId('c-vuk'), name: 'Vuk Stojanović'),
  Client(id: ClientId('c-iva'), name: 'Iva Marković'),
];

const seedProviders = [
  Provider(
    id: ProviderId('p-marko'),
    name: 'Marko „Mix“ Petrović',
    verified: true,
    genres: [Genre.hipHop, Genre.rnb],
    services: [ServiceType.mixing, ServiceType.mastering],
    priceFrom: 80,
    capacity: 3,
  ),
  Provider(
    id: ProviderId('p-jelena'),
    name: 'Jelena Vokal',
    verified: true,
    genres: [Genre.pop, Genre.rnb, Genre.jazz],
    services: [ServiceType.vocals],
    priceFrom: 60,
    capacity: 3,
  ),
  Provider(
    id: ProviderId('p-nikola'),
    name: 'Nikola Beats',
    verified: true,
    genres: [Genre.hipHop, Genre.electronic],
    services: [ServiceType.beat, ServiceType.mixing],
    priceFrom: 50,
    capacity: 4,
  ),
  Provider(
    id: ProviderId('p-studio'),
    name: 'Studio Dorćol',
    verified: true,
    genres: [Genre.rock, Genre.pop, Genre.folk],
    services: [ServiceType.mixing, ServiceType.mastering, ServiceType.vocals],
    priceFrom: 120,
    capacity: 3,
  ),
  Provider(
    id: ProviderId('p-ana'),
    name: 'Ana Master',
    verified: true,
    genres: [Genre.electronic, Genre.pop],
    services: [ServiceType.mastering],
    priceFrom: 40,
    capacity: 3,
  ),
  Provider(
    id: ProviderId('p-djole'),
    name: 'Đorđe Jazz Lab',
    verified: true,
    genres: [Genre.jazz],
    services: [ServiceType.mixing],
    priceFrom: 90,
    capacity: 1,
  ),
];

/// Zahtevi svih klijenata, u svim stanjima, za posao moderatora.
List<CollaborationRequest> seedRequests(DateTime now) {
  const rows = <(String, String, ServiceType, RequestStatus, String, int)>[
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
  return [
    for (final (i, (client, provider, service, status, note, revisions)) in rows.indexed)
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
  ];
}
