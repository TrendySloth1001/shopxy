import 'dart:convert';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/notification.dart';

class NotificationsRemoteDataSource {
  const NotificationsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<NotificationsPage> list({
    bool unreadOnly = false,
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.get(
      '/notifications',
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (unreadOnly) 'unreadOnly': 'true',
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load notifications: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (json['data'] as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationsPage(items: data, unread: (json['unread'] as int?) ?? 0);
  }

  Future<int> unreadCount() async {
    final res = await _client.get('/notifications/unread-count');
    if (res.statusCode != 200) return 0;
    return (jsonDecode(res.body) as Map<String, dynamic>)['unread'] as int;
  }

  Future<void> markRead(int id) async {
    await _client.post('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.post('/notifications/read-all');
  }
}

class NotificationsPage {
  const NotificationsPage({required this.items, required this.unread});
  final List<AppNotification> items;
  final int unread;
}

class InvitationsRemoteDataSource {
  const InvitationsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<Invitation>> incoming({
    String status = 'ALL',
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.get(
      '/invitations/incoming',
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (status != 'ALL') 'status': status,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load invitations: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((e) => Invitation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Invitation>> outgoing({
    String status = 'ALL',
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.get(
      '/invitations/outgoing',
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (status != 'ALL') 'status': status,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load invitations: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((e) => Invitation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Invitation> send({
    required String toEmail,
    required String linkType,
    int? partyId,
    int? vendorId,
    String? message,
  }) async {
    final res = await _client.post('/invitations', body: {
      'toEmail': toEmail,
      'linkType': linkType,
      'partyId': ?partyId,
      'vendorId': ?vendorId,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error']?.toString() ?? 'Failed to send invitation');
    }
    return Invitation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Invitation> accept(int id) async {
    final res = await _client.post('/invitations/$id/accept');
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body) ?? 'Failed to accept');
    }
    return Invitation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Invitation> decline(int id) async {
    final res = await _client.post('/invitations/$id/decline');
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body) ?? 'Failed to decline');
    }
    return Invitation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> cancel(int id) async {
    final res = await _client.delete('/invitations/$id');
    if (res.statusCode != 204) {
      throw Exception(_errorMessage(res.body) ?? 'Failed to cancel');
    }
  }

  String? _errorMessage(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error']?.toString();
    } catch (_) {
      return null;
    }
  }
}
