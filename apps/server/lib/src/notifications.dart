import 'dart:io';

import 'package:domain/domain.dart';

/// Spoljni servis teme: obaveštenje pružaocu da je stigao novi zahtev (mejl, push…).
///
/// Poziva ga samo server, iza ovog porta; ključ je samo u podešavanjima servera (`NOTIFY_API_KEY`),
/// nikad u aplikaciji. Za KT2 je dovoljna lažna implementacija.
abstract interface class NotificationPort {
  Future<void> newRequest(CollaborationRequest request, Provider provider);
}

/// Lažna implementacija: ne šalje ništa napolje, samo beleži šta bi poslala. Ključ se ne ispisuje.
final class FakeNotifications implements NotificationPort {
  FakeNotifications({required String? apiKey, IOSink? log})
    : _configured = apiKey != null && apiKey.isNotEmpty,
      _log = log ?? stdout;

  final bool _configured;
  final IOSink _log;

  /// Šta je „poslato“; testovi ovde proveravaju poziv.
  final sent = <({RequestId request, ProviderId provider})>[];

  @override
  Future<void> newRequest(CollaborationRequest request, Provider provider) async {
    sent.add((request: request.id, provider: provider.id));
    final key = _configured ? 'ključ postavljen' : 'bez ključa';
    _log.writeln('[obaveštenje, lažno, $key] ${provider.name}: novi zahtev ${request.id.value}');
  }
}
