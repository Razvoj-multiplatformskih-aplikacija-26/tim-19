import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:api_mapping/api_mapping.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// Isto što se desi na mreži: u tekst i nazad.
Map<String, Object?> overTheWire(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  final createdAt = DateTime.utc(2026, 11, 3, 12, 48);

  CollaborationRequest request(RequestStatus status) => CollaborationRequest(
    id: const RequestId('r-1'),
    clientId: const ClientId('c-sava'),
    providerId: const ProviderId('p-marko'),
    service: ServiceType.mastering,
    note: 'Mastering singla, -9 LUFS.',
    status: status,
    createdAt: createdAt,
    revisions: 1,
  );

  group('modeli tamo i nazad', () {
    test('zahtev u svakom stanju ostaje isti', () {
      for (final status in RequestStatus.values) {
        final sent = request(status);
        expect(RequestDto.fromJson(overTheWire(sent.toDto().toJson())).toDomain(), sent);
      }
    });

    test('pružalac ostaje isti, a slobodna mesta nosi ugovor', () {
      const provider = Provider(
        id: ProviderId('p-marko'),
        name: 'Marko „Mix“ Petrović',
        verified: true,
        genres: Genre.values,
        services: ServiceType.values,
        priceFrom: 80,
        capacity: 3,
        bio: 'Miks i mastering.',
      );
      final dto = ProviderDto.fromJson(overTheWire(provider.toDto(freeSlots: 2).toJson()));
      expect(dto.toDomain(), provider);
      expect(dto.freeSlots, 2);
    });

    test('klijent i korisnik ostaju isti', () {
      const client = Client(id: ClientId('c-sava'), name: 'Sava Radošević');
      expect(ClientDto.fromJson(overTheWire(client.toDto().toJson())).toDomain(), client);
      for (final role in Role.values) {
        final user = User(id: const UserId('u-1'), name: 'Ime', role: role);
        expect(UserDto.fromJson(overTheWire(user.toDto().toJson())).toDomain(), user);
      }
    });

    test('novi zahtev: klijent dolazi iz prijave, ne iz tela', () {
      const draft = NewRequest(
        clientId: ClientId('c-sava'),
        providerId: ProviderId('p-marko'),
        service: ServiceType.mixing,
        note: 'Miks',
      );
      final body = NewRequestDto.fromJson(overTheWire(draft.toDto().toJson()));
      expect(body.toDomain(clientId: const ClientId('c-sava')), draft);
      expect(body.toDomain(clientId: const ClientId('c-drugi')).clientId, const ClientId('c-drugi'));
    });
  });

  group('stara verzija aplikacije ne pada', () {
    test('zahtev u nepoznatom stanju se preskače, ostali ostaju', () {
      final known = request(RequestStatus.sent).toDto();
      final unknown = RequestDto.fromJson(
        overTheWire(request(RequestStatus.sent).toDto().toJson())..['status'] = 'archived',
      );
      expect(unknown.toDomain(), isNull);
      expect(requestsFromDtos([known, unknown]), [request(RequestStatus.sent)]);
    });

    test('nepoznat žanr i usluga pružaoca se preskaču', () {
      final dto = ProviderDto.fromJson({
        'id': 'p-1',
        'name': 'P',
        'verified': true,
        'genres': ['pop', 'k-pop'],
        'services': ['mixing', 'podcast'],
        'priceFrom': 50,
        'capacity': 3,
        'freeSlots': 3,
      });
      final provider = dto.toDomain();
      expect(provider.genres, [Genre.pop]);
      expect(provider.services, [ServiceType.mixing]);
    });

    test('nepoznat kôd greške postaje ServerRejected', () {
      const problem = ProblemDto(status: 422, code: 'deadline-too-close', title: 'Deadline too close');
      expect(problem.toDomainError(), const ServerRejected('deadline-too-close'));
    });

    test('poznat kôd sa nepoznatim stanjem postaje ServerRejected', () {
      const problem = ProblemDto(status: 409, code: ErrorCodes.staleRequest, title: 'Stale', state: 'archived');
      expect(problem.toDomainError(), const ServerRejected(ErrorCodes.staleRequest));
    });

    test('poznat kôd bez podataka pravila postaje ServerRejected', () {
      const problem = ProblemDto(status: 422, code: ErrorCodes.noteTooLong, title: 'Note too long');
      expect(problem.toDomainError(), const ServerRejected(ErrorCodes.noteTooLong));
    });
  });

  group('na serveru, pogrešno telo je 400', () {
    test('nepoznata usluga u novom zahtevu', () {
      const body = NewRequestDto(providerId: 'p-1', service: 'podcast', note: 'x');
      expect(() => body.toDomain(clientId: const ClientId('c-1')), throwsFormatException);
    });

    test('nepoznato stanje u akciji', () {
      expect(() => statusFromDtoStrict('archived'), throwsFormatException);
    });
  });

  test('svaka greška iz domena ima kôd i vraća se kao ista greška', () {
    final errors = <DomainError>[
      const InvalidTransition(from: RequestStatus.accepted, to: RequestStatus.cancelled, role: Role.client),
      const CancelNotAllowed(RequestStatus.accepted),
      const RevisionLimitReached(max: maxRevisions),
      const NoFreeSlots(capacity: 3),
      const NoteTooLong(501, max: maxNoteLength),
      const NoteEmpty(),
      const ProviderNotListed(),
      const ServiceNotOffered(ServiceType.vocals),
      const RequestClosed(RequestStatus.completed),
      const NotDelivered(RequestStatus.inProgress),
      const NotFound(),
      const NotAllowed(),
      const WrongApp(ClientApp.backoffice),
      const WrongApp(ClientApp.mobile),
      const StaleRequest(RequestStatus.accepted),
      const InvalidCredentials(),
      const ServerRejected('novo-pravilo'),
    ];
    final codes = <String>{};
    for (final error in errors) {
      final problem = ProblemDto.fromJson(overTheWire(error.toProblem().toJson()));
      codes.add(problem.code);
      expect(problem.status, inInclusiveRange(400, 499), reason: '$error');
      expect(problem.toDomainError(), error, reason: '$error');
    }
    expect(codes, hasLength(errors.length - 1), reason: 'svaka greška ima svoj kôd (WrongApp dva puta)');
  });

  test('statusi grešaka: prava 403, nepostojeće 404, sukob 409, neispravan unos 422', () {
    expect(const NotAllowed().toProblem().status, 403);
    expect(const WrongApp(ClientApp.backoffice).toProblem().status, 403);
    expect(const NotFound().toProblem().status, 404);
    expect(const NoFreeSlots(capacity: 3).toProblem().status, 409);
    expect(const StaleRequest(RequestStatus.accepted).toProblem().status, 409);
    expect(const NoteTooLong(501, max: 500).toProblem().status, 422);
  });

  test('granica pravila putuje sa greškom', () {
    final problem = const NoteTooLong(501, max: maxNoteLength).toProblem();
    expect([problem.value, problem.max], [501, maxNoteLength]);
    expect(const NoFreeSlots(capacity: 4).toProblem().max, 4);
  });
}
