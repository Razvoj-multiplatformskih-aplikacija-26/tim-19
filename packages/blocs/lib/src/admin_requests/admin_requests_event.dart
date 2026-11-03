part of 'admin_requests_bloc.dart';

enum AdminColumn { createdAt, client, provider, service, status }

enum ModeratorAction { cancel, close, reopen }

sealed class AdminRequestsEvent {
  const AdminRequestsEvent();
}

final class LoadAdminRequests extends AdminRequestsEvent {
  const LoadAdminRequests();
}

final class RetryAdminRequests extends AdminRequestsEvent {
  const RetryAdminRequests();
}

/// Klik na istu kolonu obrće smer.
final class AdminSortChanged extends AdminRequestsEvent {
  const AdminSortChanged(this.column);

  final AdminColumn column;
}

/// `null` znači sva stanja.
final class AdminStatusFilterChanged extends AdminRequestsEvent {
  const AdminStatusFilterChanged(this.status);

  final RequestStatus? status;
}

final class AdminSearchChanged extends AdminRequestsEvent {
  const AdminSearchChanged(this.query);

  final String query;
}

final class AdminRequestSelected extends AdminRequestsEvent {
  const AdminRequestSelected(this.id);

  final RequestId? id;
}

/// Pomera izbor po vidljivim redovima: -1 gore, 1 dole.
final class AdminSelectionMoved extends AdminRequestsEvent {
  const AdminSelectionMoved(this.delta);

  final int delta;
}

final class ModeratorActionRequested extends AdminRequestsEvent {
  const ModeratorActionRequested(this.action, this.id);

  final ModeratorAction action;
  final RequestId id;
}

final class AdminNoticeShown extends AdminRequestsEvent {
  const AdminNoticeShown();
}
