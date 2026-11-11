import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';

import 'catalog_mapping.dart';

extension RequestStatusMapping on RequestStatus {
  String toDto() => switch (this) {
    RequestStatus.sent => RequestStatusDto.sent,
    RequestStatus.accepted => RequestStatusDto.accepted,
    RequestStatus.inProgress => RequestStatusDto.inProgress,
    RequestStatus.delivered => RequestStatusDto.delivered,
    RequestStatus.completed => RequestStatusDto.completed,
    RequestStatus.rejected => RequestStatusDto.rejected,
    RequestStatus.cancelled => RequestStatusDto.cancelled,
  };
}

/// Stanje sa mreže; `null` za stanje koje ova verzija ne poznaje (novo stanje na serveru).
RequestStatus? statusFromDto(String value) => switch (value) {
  RequestStatusDto.sent => RequestStatus.sent,
  RequestStatusDto.accepted => RequestStatus.accepted,
  RequestStatusDto.inProgress => RequestStatus.inProgress,
  RequestStatusDto.delivered => RequestStatus.delivered,
  RequestStatusDto.completed => RequestStatus.completed,
  RequestStatusDto.rejected => RequestStatus.rejected,
  RequestStatusDto.cancelled => RequestStatus.cancelled,
  _ => null,
};

/// Stanje iz tela zahteva koji stiže na server; nepoznato stanje je loš zahtev (400).
RequestStatus statusFromDtoStrict(String value) =>
    statusFromDto(value) ?? (throw FormatException('Nepoznato stanje zahteva', value));

extension CollaborationRequestMapping on CollaborationRequest {
  RequestDto toDto() => RequestDto(
    id: id.value,
    clientId: clientId.value,
    providerId: providerId.value,
    service: service.toDto(),
    note: note,
    status: status.toDto(),
    createdAt: createdAt,
    revisions: revisions,
  );
}

extension RequestDtoMapping on RequestDto {
  /// Zahtev u domenu; `null` kada stanje ili usluga nisu poznati ovoj verziji aplikacije.
  CollaborationRequest? toDomain() {
    final status = statusFromDto(this.status);
    final service = serviceFromDto(this.service);
    if (status == null || service == null) return null;
    return CollaborationRequest(
      id: RequestId(id),
      clientId: ClientId(clientId),
      providerId: ProviderId(providerId),
      service: service,
      note: note,
      status: status,
      createdAt: createdAt,
      revisions: revisions,
    );
  }
}

/// Lista sa mreže: zahtev koji stara verzija ne razume preskače, umesto da padne cela lista.
List<CollaborationRequest> requestsFromDtos(Iterable<RequestDto> dtos) => [...dtos.map((d) => d.toDomain()).nonNulls];

extension NewRequestMapping on NewRequest {
  /// Klijent se ne šalje; server ga zna iz prijave.
  NewRequestDto toDto() => NewRequestDto(providerId: providerId.value, service: service.toDto(), note: note);
}

extension NewRequestDtoMapping on NewRequestDto {
  /// Na serveru: [clientId] dolazi iz prijave, nikad iz tela. Nepoznata usluga je loš zahtev (400).
  NewRequest toDomain({required ClientId clientId}) => NewRequest(
    clientId: clientId,
    providerId: ProviderId(providerId),
    service: serviceFromDto(service) ?? (throw FormatException('Nepoznata usluga', service)),
    note: note,
  );
}
