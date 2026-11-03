import 'package:domain/domain.dart';

/// Prijavljeni klijent dok prijava ne stigne u KT2.
const me = Client(id: ClientId('c-sava'), name: 'Sava Radošević');

const otherClients = [
  Client(id: ClientId('c-mila'), name: 'Mila Jovanović'),
  Client(id: ClientId('c-luka'), name: 'Luka Ilić'),
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
  Provider(
    id: ProviderId('p-ceka'),
    name: 'Čeka Verifikaciju',
    verified: false,
    genres: [Genre.rock],
    services: [ServiceType.mixing],
    priceFrom: 70,
    capacity: 3,
  ),
];

/// Bar deset zahteva prijavljenog klijenta u svim stanjima, plus zahtevi drugih klijenata
/// koji zauzimaju mesta kod pružalaca.
List<CollaborationRequest> seedRequests(DateTime now) {
  var n = 0;
  CollaborationRequest r(
    String provider,
    ServiceType service,
    RequestStatus status,
    String note, {
    Client client = me,
    int daysAgo = 0,
    int revisions = 0,
  }) => CollaborationRequest(
    id: RequestId('r-${++n}'),
    clientId: client.id,
    providerId: ProviderId(provider),
    service: service,
    note: note,
    status: status,
    createdAt: now.subtract(Duration(days: daysAgo, hours: n)),
    revisions: revisions,
  );

  return [
    r('p-marko', ServiceType.mixing, RequestStatus.sent, 'Miks singla „Noćna vožnja“, 32 traka, referenca u prilogu.'),
    r('p-jelena', ServiceType.vocals, RequestStatus.sent, 'Prateći vokali za refren, dva glasa.', daysAgo: 1),
    r('p-ana', ServiceType.mastering, RequestStatus.accepted, 'Mastering EP-a od 4 pesme za Spotify.', daysAgo: 2),
    r('p-nikola', ServiceType.beat, RequestStatus.inProgress, 'Trep bit, 140 BPM, mračna atmosfera.', daysAgo: 4),
    r(
      'p-studio',
      ServiceType.mixing,
      RequestStatus.inProgress,
      'Miks live snimka benda, 12 kanala.',
      daysAgo: 6,
      revisions: 1,
    ),
    r('p-marko', ServiceType.mastering, RequestStatus.delivered, 'Mastering singla, glasnoća -9 LUFS.', daysAgo: 8),
    r(
      'p-nikola',
      ServiceType.mixing,
      RequestStatus.delivered,
      'Miks bita sa vokalom.',
      daysAgo: 10,
      revisions: maxRevisions,
    ),
    r('p-ana', ServiceType.mastering, RequestStatus.completed, 'Mastering albuma za vinil.', daysAgo: 20),
    r('p-jelena', ServiceType.vocals, RequestStatus.completed, 'Glavni vokal za pop pesmu.', daysAgo: 30),
    r('p-djole', ServiceType.mixing, RequestStatus.rejected, 'Miks trio snimka.', daysAgo: 12),
    r('p-studio', ServiceType.vocals, RequestStatus.cancelled, 'Snimanje vokala u studiju.', daysAgo: 15),
    r('p-marko', ServiceType.mixing, RequestStatus.inProgress, 'Miks remiksa.', client: otherClients[0], daysAgo: 3),
    r(
      'p-djole',
      ServiceType.mixing,
      RequestStatus.accepted,
      'Džez kvartet, miks.',
      client: otherClients[1],
      daysAgo: 5,
    ),
    r('p-jelena', ServiceType.vocals, RequestStatus.accepted, 'Vokal za reklamu.', client: otherClients[1], daysAgo: 2),
  ];
}
