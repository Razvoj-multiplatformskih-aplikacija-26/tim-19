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
    Actor.client: {(s, x), (d, c), (d, p)},
    Actor.provider: {(s, a), (s, r), (a, p), (p, d)},
    Actor.moderator: {(s, x), (a, x), (p, x), (d, x), (d, c), (d, p)},
  };

  for (final actor in Actor.values) {
    group('${actor.name}:', () {
      for (final from in RequestStatus.values) {
        for (final to in RequestStatus.values) {
          final expected = allowed[actor]!.contains((from, to));
          test('${from.name} -> ${to.name} ${expected ? 'je dozvoljen' : 'nije dozvoljen'}', () {
            expect(canTransition(from, to, actor), expected);
          });
        }
      }
    });
  }

  test('iz završnog stanja nema prelaza ni za koga', () {
    for (final from in RequestStatus.values.where((s) => s.isFinal)) {
      for (final to in RequestStatus.values) {
        for (final actor in Actor.values) {
          expect(canTransition(from, to, actor), isFalse, reason: '${from.name} -> ${to.name} (${actor.name})');
        }
      }
    }
  });

  test('mesto zauzimaju samo zahtevi koji nisu završeni, odbijeni ni otkazani', () {
    expect(RequestStatus.values.where((s) => s.occupiesSlot), [s, a, p, d]);
  });
}
