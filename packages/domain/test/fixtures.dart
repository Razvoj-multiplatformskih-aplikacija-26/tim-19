import 'package:domain/domain.dart';

final createdAt = DateTime.utc(2026, 11, 1, 12);

const provider = Provider(
  id: ProviderId('p-1'),
  name: 'Marko Miks',
  verified: true,
  genres: [Genre.hipHop, Genre.rnb],
  services: [ServiceType.mixing, ServiceType.mastering],
  priceFrom: 80,
  capacity: 3,
);

const unverified = Provider(
  id: ProviderId('p-2'),
  name: 'Novi Producent',
  verified: false,
  genres: [Genre.pop],
  services: [ServiceType.beat],
  priceFrom: 50,
  capacity: 3,
);

CollaborationRequest request({
  String id = 'r-1',
  RequestStatus status = RequestStatus.sent,
  int revisions = 0,
  ProviderId providerId = const ProviderId('p-1'),
  ClientId clientId = const ClientId('c-1'),
}) => CollaborationRequest(
  id: RequestId(id),
  clientId: clientId,
  providerId: providerId,
  service: ServiceType.mixing,
  note: 'Miks singla, 24 traka.',
  status: status,
  createdAt: createdAt,
  revisions: revisions,
);
