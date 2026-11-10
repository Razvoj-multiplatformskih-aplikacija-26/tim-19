import 'json.dart';

/// Deo velike liste: [items] počev od [offset], najviše [limit], od ukupno [total] zapisa.
final class PageDto<T> {
  const PageDto({required this.items, required this.total, required this.limit, required this.offset});

  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  Map<String, Object?> toJson(Map<String, Object?> Function(T item) itemToJson) => {
    'items': [for (final item in items) itemToJson(item)],
    'total': total,
    'limit': limit,
    'offset': offset,
  };

  factory PageDto.fromJson(Map<String, Object?> json, T Function(Map<String, Object?> json) itemFromJson) => PageDto(
    items: [for (final item in jsonObjects(json, 'items')) itemFromJson(item)],
    total: jsonInt(json, 'total'),
    limit: jsonInt(json, 'limit'),
    offset: jsonInt(json, 'offset'),
  );
}
