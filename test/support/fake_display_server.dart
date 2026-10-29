import 'package:hermes_app/src/bot_screen/bot_screen_viewer_ids.dart';

import 'fake_gateway.dart';

/// The profile key every status and broadcast of a [FakeDisplayServer]
/// carries.
const fakeDisplayProfileKey = '/home/u/.hermes/profiles/work';

/// The display methods of Hermes' gateway as `methods_display.py` answers
/// them, on a [FakeGateway]: viewer ids are minted per connection and honoured
/// only on the connection that minted them, `display.lease.acquire` takes the
/// lease for a minted id (last writer wins), a release by a viewer that does
/// not hold it is ignored and answers the real lease, and a forced release
/// frees whoever holds it. Every lease change is broadcast as `display.lease`
/// unless [broadcasts] is off.
class FakeDisplayServer {
  FakeDisplayServer(this.gateway, {required this.connection}) {
    gateway.handlers['display.status'] = (_) => _status();
    gateway.handlers['display.observe'] = _observe;
    gateway.handlers['display.lease.acquire'] = _acquire;
    gateway.handlers['display.lease.release'] = _release;
  }

  final FakeGateway gateway;

  /// The index of the gateway connection a request arrives on (how many the
  /// client opened so far).
  final int Function() connection;

  bool running = true;
  bool broadcasts = true;

  /// Whether `display.lease.acquire` answers `viewer_mismatch` whatever the id.
  bool refuseAcquire = false;

  String holder = 'agent';
  String? holderId;
  int epoch = 1;

  final _minted = <int, Set<String>>{};
  var _mints = 0;

  /// The ids `display.observe` was asked for, in order (`null` for none).
  final observedWith = <String?>[];

  /// The ids `display.lease.acquire` named, in order.
  final acquired = <String>[];

  /// The `viewer_id` of each release (`null` for a forced one).
  final released = <String?>[];

  /// The ids minted so far, in order.
  final mintedIds = <String>[];

  /// Forgets what connection [index] minted, as if it were another one.
  void forget(int index) => _minted.remove(index);

  /// The lease as `public_view` shows it.
  Map<String, Object?> get lease => {
    'holder': holder,
    'viewer_id': null,
    'viewer_hash': holderId == null
        ? null
        : BotScreenViewerIds.hashOf(holderId!),
    'since': 1.0,
    'reason': '',
    'epoch': epoch,
  };

  Map<String, Object?> _status() => {
    'profile': 'work',
    'supported': true,
    'installed': true,
    'missing': <String>[],
    'running': running,
    'geometry': '8x4',
    'placement': 'gateway',
    'lease': lease,
    'profile_key': fakeDisplayProfileKey,
  };

  Set<String> get _mine => _minted.putIfAbsent(connection(), () => {});

  Map<String, Object?> _observe(Map<String, Object?> params) {
    if (!running) throw const FakeRpcError(5300, 'not running');
    final requested = params['viewer_id'] as String?;
    observedWith.add(requested);
    final String id;
    if (requested != null && _mine.contains(requested)) {
      id = requested;
    } else {
      id = 'viewer-${++_mints}';
      _mine.add(id);
      mintedIds.add(id);
    }
    return {
      'ticket': 'ticket-$id-${observedWith.length}',
      'path': '/api/display/ws',
      'viewer_id': id,
      ..._status(),
    };
  }

  Never _mismatch() => throw const FakeRpcError(
    5300,
    'viewer_id was not minted for this connection',
    {'code': 'viewer_mismatch'},
  );

  Map<String, Object?> _acquire(Map<String, Object?> params) {
    final id = params['viewer_id'] as String? ?? '';
    acquired.add(id);
    if (refuseAcquire || !_mine.contains(id)) _mismatch();
    takeBy(id);
    return {'lease': lease};
  }

  Map<String, Object?> _release(Map<String, Object?> params) {
    final id = params['viewer_id'] as String?;
    final force = params['force'] == true;
    released.add(id);
    if (id != null && !force && !_mine.contains(id)) _mismatch();
    if (id == null && !force && holder == 'human') {
      throw const FakeRpcError(5300, 'viewer_id required', {
        'code': 'viewer_mismatch',
      });
    }
    if (holder == 'human' && (force || holderId == id)) {
      holder = 'agent';
      holderId = null;
      epoch++;
      _broadcast();
    }
    return {'lease': lease};
  }

  /// A viewer takes the lease, as another device would. A lease already
  /// theirs changes nothing.
  void takeBy(String id) {
    if (holder == 'human' && holderId == id) return;
    holder = 'human';
    holderId = id;
    epoch++;
    _broadcast();
  }

  /// Hermes takes the lease back, as when someone else forces a release.
  void giveToAgent() {
    holder = 'agent';
    holderId = null;
    epoch++;
    _broadcast();
  }

  void _broadcast() {
    if (!broadcasts) return;
    gateway.event('display.lease', '', {
      'profile_key': fakeDisplayProfileKey,
      'lease': lease,
    });
  }
}
