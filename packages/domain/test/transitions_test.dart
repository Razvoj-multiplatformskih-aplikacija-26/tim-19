import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const s = RequestStatus.sent;
  const a = RequestStatus.accepted;
  const p = RequestStatus.inProgress;
  const d = RequestStatus.delivered;
  const c = RequestStatus.completed;
  const r = RequestStatus.rejected;
  const x = RequestStatus.cancelled;

  const allowed = {
    Role.client: {(s, x), (d, c), (d, p)},
    Role.provider: {(s, a), (s, r), (a, p), (p, d)},
    Role.moderator: {(s, x), (a, x), (p, x), (d, x), (d, c), (d, p)},
  };

  for (final role in Role.values) {
    group('${role.name}:', () {
      for (final from in RequestStatus.values) {
        for (final to in RequestStatus.values) {
          final expected = allowed[role]!.contains((from, to));
          test('${from.name} -> ${to.name} ${expected ? 'je dozvoljen' : 'nije dozvoljen'}', () {
            expect(canTransition(from, to, role), expected);
          });
        }
      }
    });
  }

  test('iz završnog stanja nema prelaza ni za koga', () {
    for (final from in RequestStatus.values.where((s) => s.isFinal)) {
      for (final to in RequestStatus.values) {
        for (final role in Role.values) {
          expect(canTransition(from, to, role), isFalse, reason: '${from.name} -> ${to.name} (${role.name})');
        }
      }
    }
  });

  test('mesto zauzimaju samo zahtevi koji nisu završeni, odbijeni ni otkazani', () {
    expect(RequestStatus.values.where((s) => s.occupiesSlot), [s, a, p, d]);
  });
}
