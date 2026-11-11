part of 'admin_requests_bloc.dart';

const _keep = Object();

sealed class AdminRequestsState extends Equatable {
  const AdminRequestsState();

  @override
  List<Object?> get props => const [];
}

final class AdminRequestsLoading extends AdminRequestsState {
  const AdminRequestsLoading();
}

final class AdminRequestsError extends AdminRequestsState {
  const AdminRequestsError(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];
}

final class AdminRequestsEmpty extends AdminRequestsState {
  const AdminRequestsEmpty();
}

final class AdminRequestsLoaded extends AdminRequestsState {
  const AdminRequestsLoaded({
    required this.requests,
    required this.providers,
    required this.clients,
    int? total,
    this.loadingMore = false,
    this.sortColumn = AdminColumn.createdAt,
    this.ascending = false,
    this.statusFilter,
    this.query = '',
    this.selectedId,
    this.busyId,
    this.notice,
  }) : total = total ?? requests.length;

  /// Učitani zahtevi (jedna ili više strana).
  final List<CollaborationRequest> requests;

  /// Koliko zahteva ima na serveru po trenutnom filteru stanja.
  final int total;

  /// Sledeća strana se upravo učitava.
  final bool loadingMore;
  final Map<ProviderId, Provider> providers;
  final Map<ClientId, Client> clients;
  final AdminColumn sortColumn;
  final bool ascending;
  final RequestStatus? statusFilter;
  final String query;
  final RequestId? selectedId;
  final RequestId? busyId;
  final AdminNotice? notice;

  bool get isBusy => busyId != null;

  /// Na serveru ima još zahteva koji nisu učitani.
  bool get hasMore => requests.length < total;

  String providerName(CollaborationRequest r) => providers[r.providerId]?.name ?? r.providerId.value;

  String clientName(CollaborationRequest r) => clients[r.clientId]?.name ?? r.clientId.value;

  /// Redovi tabele posle filtera, pretrage i sortiranja.
  List<CollaborationRequest> get visible {
    final needle = query.trim().toLowerCase();
    final rows = [
      for (final r in requests)
        if ((statusFilter == null || r.status == statusFilter) &&
            (needle.isEmpty ||
                providerName(r).toLowerCase().contains(needle) ||
                clientName(r).toLowerCase().contains(needle) ||
                r.id.value.toLowerCase().contains(needle)))
          r,
    ];
    int compare(CollaborationRequest a, CollaborationRequest b) => switch (sortColumn) {
      AdminColumn.createdAt => a.createdAt.compareTo(b.createdAt),
      AdminColumn.client => clientName(a).compareTo(clientName(b)),
      AdminColumn.provider => providerName(a).compareTo(providerName(b)),
      AdminColumn.service => a.service.index.compareTo(b.service.index),
      AdminColumn.status => a.status.index.compareTo(b.status.index),
    };
    rows.sort((a, b) {
      final order = compare(a, b);
      return ascending ? order : -order;
    });
    return rows;
  }

  CollaborationRequest? byId(RequestId id) => requests.where((r) => r.id == id).firstOrNull;

  CollaborationRequest? get selected => selectedId == null ? null : byId(selectedId!);

  /// Pravilo iz domena odlučuje da li je akcija dostupna za zahtev.
  bool canApply(ModeratorAction action, CollaborationRequest request) => switch (action) {
    ModeratorAction.cancel => moderatorCanCancel(request).isSuccess,
    ModeratorAction.close => moderatorCanClose(request).isSuccess,
    ModeratorAction.reopen => moderatorCanReopen(request).isSuccess,
  };

  /// Zašto nad zahtevom nema nijedne akcije (završen, odbijen ili otkazan); inače `null`.
  DomainError? whyLocked(CollaborationRequest request) => moderatorCanCancel(request).errorOrNull;

  AdminRequestsLoaded moveSelection(int delta) {
    final rows = visible;
    if (rows.isEmpty) return this;
    final index = rows.indexWhere((r) => r.id == selectedId);
    final next = index < 0 ? (delta > 0 ? 0 : rows.length - 1) : (index + delta).clamp(0, rows.length - 1);
    return copyWith(selectedId: rows[next].id);
  }

  AdminRequestsLoaded replaced(CollaborationRequest request) =>
      copyWith(requests: [for (final r in requests) r.id == request.id ? request : r]);

  AdminRequestsLoaded copyWith({
    List<CollaborationRequest>? requests,
    int? total,
    bool? loadingMore,
    AdminColumn? sortColumn,
    bool? ascending,
    Object? statusFilter = _keep,
    String? query,
    Object? selectedId = _keep,
    Object? busyId = _keep,
    Object? notice = _keep,
  }) => AdminRequestsLoaded(
    requests: requests ?? this.requests,
    total: total ?? this.total,
    loadingMore: loadingMore ?? this.loadingMore,
    providers: providers,
    clients: clients,
    sortColumn: sortColumn ?? this.sortColumn,
    ascending: ascending ?? this.ascending,
    statusFilter: identical(statusFilter, _keep) ? this.statusFilter : statusFilter as RequestStatus?,
    query: query ?? this.query,
    selectedId: identical(selectedId, _keep) ? this.selectedId : selectedId as RequestId?,
    busyId: identical(busyId, _keep) ? this.busyId : busyId as RequestId?,
    notice: identical(notice, _keep) ? this.notice : notice as AdminNotice?,
  );

  @override
  List<Object?> get props => [
    requests,
    total,
    loadingMore,
    providers,
    clients,
    sortColumn,
    ascending,
    statusFilter,
    query,
    selectedId,
    busyId,
    notice,
  ];
}

sealed class AdminNotice extends Equatable {
  const AdminNotice();
}

/// Obaveštenje o akciji moderatora nad zahtevom.
sealed class ModeratorNotice extends AdminNotice {
  const ModeratorNotice(this.action);

  final ModeratorAction action;

  @override
  List<Object?> get props => [action];
}

/// Sledeća strana nije stigla (server nije dostupan); učitane strane ostaju.
final class AdminLoadFailed extends AdminNotice {
  const AdminLoadFailed(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];
}

final class ModeratorActionDone extends ModeratorNotice {
  const ModeratorActionDone(super.action, this.request);

  final CollaborationRequest request;

  @override
  List<Object?> get props => [action, request];
}

final class ModeratorActionRejected extends ModeratorNotice {
  const ModeratorActionRejected(super.action, this.error);

  final DomainError error;

  @override
  List<Object?> get props => [action, error];
}

final class ModeratorActionFailed extends ModeratorNotice {
  const ModeratorActionFailed(super.action, this.cause);

  final Object cause;

  @override
  List<Object?> get props => [action, cause];
}
