import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:api_mapping/api_mapping.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart' hide Result;
import 'package:relic/relic.dart' hide Result;

import 'http.dart';
import 'notifications.dart';
import 'sessions.dart';
import 'store.dart';

/// Katalog, klijenti i zahtevi. Svaki upis ide kroz isti domenski kôd kao na klijentu: učitaj, pitaj domen
/// (pravo, pravilo, prelaz), pa upiši. Ko poziva zna se samo iz prijave ([currentSession]).
final class RequestHandlers {
  RequestHandlers({required this.database, required this.notifications, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Pool<void> database;
  final NotificationPort notifications;
  final DateTime Function() _now;

  // Katalog i klijenti.

  /// Katalog verifikovanih pružalaca sa slobodnim mestima; javan, bez prijave. Moderator vidi i neverifikovane.
  /// Slobodna mesta računa isto pravilo iz domena (`freeSlots`) nad zahtevima svih klijenata.
  Future<Response> providers(Request request) async {
    final store = SoundStore(database);
    final all = await store.providers();
    final active = await store.activeRequests();
    final visible = _isModerator(request) ? all : catalog(all);
    return json(200, [for (final p in visible) p.toDto(freeSlots: freeSlots(p, active)).toJson()]);
  }

  Future<Response> provider(Request request) async {
    final store = SoundStore(database);
    final found = await store.provider(ProviderId(request.rawPathParameters[#id]!));
    if (found == null || (!isListedInCatalog(found) && !_isModerator(request))) return problem(const NotFound());
    final active = await store.activeRequests(providerId: found.id);
    return json(200, found.toDto(freeSlots: freeSlots(found, active)).toJson());
  }

  /// Imena klijenata za tabelu moderatora.
  Future<Response> clients(Request request) async {
    if (!AccessPolicy.canViewAll(_user(request))) return problem(const NotAllowed());
    return json(200, [for (final c in await SoundStore(database).clients()) c.toDto().toJson()]);
  }

  // Zahtevi.

  /// Strana zahteva koje korisnik sme da vidi: klijent svoje, pružalac upućene njemu, moderator sve.
  Future<Response> requests(Request request) async {
    final user = _user(request);
    final query = request.queryParameters.raw;
    final status = switch (query[ApiQuery.status]) {
      null || '' => null,
      final value => statusFromDtoStrict(value),
    };
    final limit = _intQuery(query[ApiQuery.limit], ApiQuery.defaultLimit, min: 1, max: ApiQuery.maxLimit);
    final offset = _intQuery(query[ApiQuery.offset], 0, min: 0);
    final page = await SoundStore(database).requests(
      clientId: user.role == Role.client ? user.asClient : null,
      providerId: user.role == Role.provider ? user.asProvider : null,
      status: status,
      limit: limit,
      offset: offset,
    );
    // Filter iznad sužava upit; AccessPolicy ostaje poslednja reč za svaki zapis.
    final visible = [
      for (final r in page.items)
        if (AccessPolicy.canView(user, r)) r,
    ];
    final dto = PageDto(items: visible, total: page.total, limit: limit, offset: offset);
    return json(200, dto.toJson((r) => r.toDto().toJson()));
  }

  Future<Response> find(Request request) async {
    final found = await SoundStore(database).request(_requestId(request));
    if (found == null) return problem(const NotFound());
    if (!AccessPolicy.canView(_user(request), found)) return problem(const NotAllowed());
    return json(200, found.toDto().toJson());
  }

  /// Novi zahtev. Pravilo o slobodnim mestima zavisi od zahteva drugih klijenata, pa o njemu konačno odlučuje
  /// server: red pružaoca je zaključan do kraja transakcije, pa istovremeni zahtevi za istog pružaoca prolaze
  /// jedan po jedan i svaki broji mesta posle prethodnog. Za poslednje mesto prolazi tačno jedan.
  Future<Response> create(Request request) async {
    final user = _user(request);
    final draft = NewRequestDto.fromJson(await readObject(request)).toDomain(clientId: user.asClient);
    final outcome = await database.runTx((tx) async {
      final store = SoundStore(tx);
      final provider = await store.provider(draft.providerId, lock: true);
      if (provider == null) return (const Failure<CollaborationRequest>(ProviderNotListed()), null);
      final created = createRequest(
        draft,
        by: user,
        provider: provider,
        existing: await store.activeRequests(providerId: provider.id),
        id: const RequestId('novi'),
        now: _now(),
      );
      return switch (created) {
        Success(:final value) => (Success(await store.insertNew(value)), provider),
        Failure() => (created, provider),
      };
    });
    final (result, provider) = outcome;
    if (result case Success(:final value) when provider != null) await _notify(value, provider);
    return _respond(result, status: 201);
  }

  /// Otkazivanje: klijent svoj poslat zahtev, moderator svaki nezavršen. Uloga iz prijave bira akciju iz domena.
  Future<Response> cancel(Request request) => _act(request, RequestAction.cancel);

  Future<Response> complete(Request request) => _act(request, RequestAction.complete);

  Future<Response> revise(Request request) => _act(request, RequestAction.revise);

  Future<Response> accept(Request request) => _act(request, RequestAction.accept);

  Future<Response> reject(Request request) => _act(request, RequestAction.reject);

  Future<Response> close(Request request) => _act(request, RequestAction.close);

  Future<Response> reopen(Request request) => _act(request, RequestAction.reopen);

  /// Akcija nad zahtevom u transakciji, sa zaključanim redom zahteva. Redosled: postoji li, sme li da ga vidi,
  /// da li je u stanju koje je korisnik video (inače `stale-request`), pa akcija iz domena i upis.
  Future<Response> _act(Request request, RequestAction action) async {
    final user = _user(request);
    final id = _requestId(request);
    final seen = statusFromDtoStrict(ActionDto.fromJson(await readObject(request)).from);
    final result = await database.runTx((tx) async {
      final store = SoundStore(tx);
      final stored = await store.request(id, lock: true);
      if (stored == null) return const Failure<CollaborationRequest>(NotFound());
      if (!AccessPolicy.canView(user, stored)) return const Failure<CollaborationRequest>(NotAllowed());
      if (stored.status != seen) return Failure<CollaborationRequest>(StaleRequest(stored.status));
      final next = applyAction(action, stored, by: user);
      if (next case Success(:final value)) await store.updateRequest(value, now: _now());
      return next;
    });
    return _respond(result);
  }

  Future<void> _notify(CollaborationRequest created, Provider provider) async {
    try {
      await notifications.newRequest(created, provider);
    } on Exception catch (error) {
      // Zahtev je već sačuvan; neuspelo obaveštenje ne poništava posao korisnika.
      stderr.writeln('Obaveštenje za ${created.id.value} nije poslato: $error');
    }
  }

  Response _respond(Result<CollaborationRequest> result, {int status = 200}) => switch (result) {
    Success(:final value) => json(status, value.toDto().toJson()),
    Failure(:final error) => problem(error),
  };

  User _user(Request request) => currentSession.get(request).user;

  bool _isModerator(Request request) => currentSession[request]?.user.role == Role.moderator;

  RequestId _requestId(Request request) => RequestId(request.rawPathParameters[#id]!);
}

int _intQuery(String? value, int fallback, {required int min, int? max}) {
  if (value == null || value.isEmpty) return fallback;
  final parsed = int.parse(value);
  if (parsed < min || (max != null && parsed > max)) {
    throw FormatException('Vrednost van opsega $min–${max ?? '∞'}', value);
  }
  return parsed;
}
