import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/notification.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

/// Single provider that owns notifications + invitations. Keeps the
/// unread count, the inbox feed, and both invitation lists in sync so
/// the bell badge and inbox page never disagree.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._notifsDs, this._invitesDs);

  final NotificationsRemoteDataSource _notifsDs;
  final InvitationsRemoteDataSource _invitesDs;

  // ── Notifications state ─────────────────────────────────────────
  List<AppNotification> _items = const [];
  int _unread = 0;
  bool _loadingInbox = false;
  String? _error;

  List<AppNotification> get items => _items;
  int get unread => _unread;
  bool get isLoadingInbox => _loadingInbox;
  String? get error => _error;

  /// Pending invitations addressed to current user. Populated by
  /// [loadIncoming]; surfaces on the dashboard first-login prompt.
  List<Invitation> _incoming = const [];
  List<Invitation> get incoming => _incoming;
  List<Invitation> get pendingIncoming =>
      _incoming.where((i) => i.isPending).toList(growable: false);

  /// Session-local dismissals for the home-screen invite preview. Hides
  /// the card without calling decline — the invite stays pending on the
  /// server and the user can still find it on the Invitations page.
  /// Cleared on logout / app cold start.
  final Set<String> _dismissedFromHome = <String>{};
  bool isDismissedFromHome(String id) => _dismissedFromHome.contains(id);
  void dismissFromHome(String id) {
    if (_dismissedFromHome.add(id)) notifyListeners();
  }

  /// Pending invites filtered by [_dismissedFromHome] — the list the
  /// home page's preview card should render against.
  List<Invitation> get pendingIncomingForHome => _incoming
      .where((i) => i.isPending && !_dismissedFromHome.contains(i.id))
      .toList(growable: false);

  List<Invitation> _outgoing = const [];
  List<Invitation> get outgoing => _outgoing;

  /// Whether we've already shown the first-login pending-invite prompt
  /// in this session. Reset on logout.
  bool _firstLoginPromptShown = false;
  bool get hasFirstLoginPromptBeenShown => _firstLoginPromptShown;
  void markFirstLoginPromptShown() => _firstLoginPromptShown = true;

  // ── Loading ─────────────────────────────────────────────────────

  Future<void> loadInbox({bool unreadOnly = false}) async {
    _loadingInbox = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _notifsDs.list(unreadOnly: unreadOnly);
      _items = page.items;
      _unread = page.unread;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loadingInbox = false;
      notifyListeners();
    }
  }

  /// Cheap call used on first paint / after login to wire the bell badge
  /// without paying for the full inbox.
  Future<void> refreshUnreadCount() async {
    try {
      _unread = await _notifsDs.unreadCount();
      notifyListeners();
    } catch (_) {
      // Network blips shouldn't break the UI — keep the previous count.
    }
  }

  Future<void> loadIncoming({String status = 'ALL'}) async {
    try {
      _incoming = await _invitesDs.incoming(status: status);
      notifyListeners();
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadOutgoing({String status = 'ALL'}) async {
    try {
      _outgoing = await _invitesDs.outgoing(status: status);
      notifyListeners();
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
    }
  }

  // ── Mutations ───────────────────────────────────────────────────

  Future<void> markRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final current = _items[idx];
    if (current.readAt != null) return;
    // Optimistic update — repaint immediately, then sync.
    _items = [
      ..._items.sublist(0, idx),
      AppNotification(
        id: current.id,
        kind: current.kind,
        title: current.title,
        body: current.body,
        data: current.data,
        readAt: DateTime.now(),
        createdAt: current.createdAt,
      ),
      ..._items.sublist(idx + 1),
    ];
    _unread = (_unread - 1).clamp(0, 1 << 31);
    notifyListeners();
    try {
      await _notifsDs.markRead(id);
    } catch (_) {
      // The server didn't accept — best-effort, keep optimistic state.
    }
  }

  Future<void> markAllRead() async {
    if (_unread == 0) return;
    _items = [
      for (final n in _items)
        n.readAt != null
            ? n
            : AppNotification(
                id: n.id,
                kind: n.kind,
                title: n.title,
                body: n.body,
                data: n.data,
                readAt: DateTime.now(),
                createdAt: n.createdAt,
              ),
    ];
    _unread = 0;
    notifyListeners();
    try {
      await _notifsDs.markAllRead();
    } catch (_) {}
  }

  Future<Invitation> sendInvite({
    required String toEmail,
    required String linkType,
    String? partyId,
    String? vendorId,
    String? message,
  }) async {
    final invite = await _invitesDs.send(
      toEmail: toEmail,
      linkType: linkType,
      partyId: partyId,
      vendorId: vendorId,
      message: message,
    );
    _outgoing = [invite, ..._outgoing];
    notifyListeners();
    return invite;
  }

  Future<Invitation> accept(String id) async {
    final updated = await _invitesDs.accept(id);
    _replaceIncoming(updated);
    return updated;
  }

  Future<Invitation> decline(String id) async {
    final updated = await _invitesDs.decline(id);
    _replaceIncoming(updated);
    return updated;
  }

  Future<void> cancel(String id) async {
    await _invitesDs.cancel(id);
    _outgoing = _outgoing.where((i) => i.id != id).toList();
    notifyListeners();
  }

  void _replaceIncoming(Invitation updated) {
    _incoming = [
      for (final i in _incoming)
        if (i.id == updated.id) updated else i,
    ];
    notifyListeners();
  }

  /// Called from AuthProvider after logout so the next user doesn't see
  /// the previous account's bell/inbox state.
  void reset() {
    _items = const [];
    _unread = 0;
    _incoming = const [];
    _outgoing = const [];
    _firstLoginPromptShown = false;
    notifyListeners();
  }
}
