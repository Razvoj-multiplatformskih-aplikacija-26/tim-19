import 'package:domain/domain.dart';

// Nazivi iz domena na srpskom. Domen nema tekst; tekst bira klijent.

extension RequestStatusLabel on RequestStatus {
  String get label => switch (this) {
    RequestStatus.sent => 'Poslat',
    RequestStatus.accepted => 'Prihvaćen',
    RequestStatus.inProgress => 'U izradi',
    RequestStatus.delivered => 'Isporučen',
    RequestStatus.completed => 'Završen',
    RequestStatus.rejected => 'Odbijen',
    RequestStatus.cancelled => 'Otkazan',
  };
}

extension GenreLabel on Genre {
  String get label => switch (this) {
    Genre.pop => 'Pop',
    Genre.hipHop => 'Hip-hop',
    Genre.rnb => 'R&B',
    Genre.rock => 'Rok',
    Genre.electronic => 'Elektronska',
    Genre.jazz => 'Džez',
    Genre.folk => 'Narodna',
  };
}

extension ServiceTypeLabel on ServiceType {
  String get label => switch (this) {
    ServiceType.mixing => 'Miks',
    ServiceType.mastering => 'Mastering',
    ServiceType.vocals => 'Vokali',
    ServiceType.beat => 'Bit',
  };
}

String formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.day}. ${local.month}. ${local.year}. ${two(local.hour)}:${two(local.minute)}';
}

String freeSlotsLabel(int free, int capacity) => switch (free) {
  0 => 'Nema slobodnih mesta',
  1 => 'Slobodno 1 od $capacity mesta',
  _ => 'Slobodno $free od $capacity mesta',
};
