// Stands in for NetworkManager on a private "system" bus in scripts/verify.sh:
// connectivity_plus asks it for the network state, a container has none, and
// the app's startup would otherwise fail on the unhandled D-Bus error. It owns
// the name, exports an empty object manager and does nothing else.
//
//   dart run scripts/verify_fake_nm.dart   # needs DBUS_SYSTEM_BUS_ADDRESS
import 'dart:async';
import 'dart:io';

// dbus arrives with connectivity_plus, whose Linux side this stands in for.
// ignore: depend_on_referenced_packages
import 'package:dbus/dbus.dart';

Future<void> main() async {
  final address = Platform.environment['DBUS_SYSTEM_BUS_ADDRESS'];
  if (address == null || address.isEmpty) {
    stderr.writeln('DBUS_SYSTEM_BUS_ADDRESS is not set');
    exit(2);
  }
  final client = DBusClient(DBusAddress(address));
  await client.registerObject(
    DBusObject(DBusObjectPath('/org/freedesktop'), isObjectManager: true),
  );
  await client.requestName('org.freedesktop.NetworkManager');
  stdout.writeln('ready');
  await Completer<void>().future;
}
