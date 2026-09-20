import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/device_attributes.dart';

void main() {
  test('describes an iPhone by system, version and form factor only', () {
    expect(
      describeDevice(
        os: 'ios',
        osVersion: 'Version 26.0 (Build 23A344)',
        shortestSideLogical: 393,
        buildMode: 'release',
      ),
      {
        'os.type': 'ios',
        'os.version': '26.0',
        'device.form_factor': 'phone',
        'app.build_mode': 'release',
      },
    );
  });

  test('tells a tablet from a phone by its shortest side', () {
    Object? formFactor(double side) => describeDevice(
      os: 'ios',
      osVersion: 'Version 26.0',
      shortestSideLogical: side,
      buildMode: 'release',
    )['device.form_factor'];

    expect(formFactor(599), 'phone');
    expect(formFactor(834), 'tablet');
  });

  test('a Mac is a desktop and the build number stays out', () {
    final attributes = describeDevice(
      os: 'macos',
      osVersion: 'Version 15.6.1 (Build 24G90)',
      shortestSideLogical: 900,
      buildMode: 'release',
    );

    expect(attributes['device.form_factor'], 'desktop');
    expect(attributes['os.version'], '15.6');
  });

  test('leaves out what it cannot say briefly or does not know yet', () {
    final attributes = describeDevice(
      os: 'android',
      osVersion: 'Linux 6.1.75-android14-11 #1 SMP PREEMPT',
      shortestSideLogical: 0,
      buildMode: 'release',
    );

    expect(attributes, {'os.type': 'android', 'app.build_mode': 'release'});
  });
}
