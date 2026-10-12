import 'package:flutter/material.dart';
import 'package:hermes_app/src/models/hermes_status.dart';
import 'package:hermes_app/src/screens/widgets/connection_setup_field.dart';
import 'package:hermes_app/src/screens/widgets/connection_summary.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode connectionNode() => WidgetbookFolder(
  name: 'Connection',
  children: [
    WidgetbookComponent(
      name: 'ConnectionSetupField',
      useCases: [
        ...onEachPlatform('Address', (_) => frame(const _Address())),
        ...onEachPlatform(
          'Required',
          (_) => frame(const _Address(error: 'Enter a URL')),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ConnectionSummary',
      useCases: [
        ...onEachPlatform(
          'Loading',
          (_) => frame(
            const ConnectionSummary(
              serverUrl: 'https://dashboard.example.test',
              loading: true,
            ),
          ),
        ),
        ...onEachPlatform(
          'Failed',
          (_) => frame(
            const ConnectionSummary(
              serverUrl: 'https://dashboard.example.test',
              error: 'The dashboard is unavailable. Pull to refresh or use Refresh.',
            ),
          ),
        ),
        ...onEachPlatform(
          'Loopback',
          (_) => frame(
            const ConnectionSummary(
              serverUrl: 'http://127.0.0.1:9119',
              status: HermesStatus(
                authRequired: false,
                authProviders: [],
                authFlows: [],
                version: '0.21.4',
              ),
            ),
          ),
        ),
        ...onEachPlatform(
          'Signed in',
          (_) => frame(
            const ConnectionSummary(
              serverUrl: 'https://dashboard.example.test/long-dashboard-prefix',
              identityName: 'A teammate with a longer display name',
              provider: 'oidc',
              status: HermesStatus(
                authRequired: true,
                authProviders: ['oidc', 'basic'],
                authFlows: [],
                version: '0.21.4',
              ),
            ),
          ),
        ),
      ],
    ),
  ],
);

class _Address extends StatefulWidget {
  const _Address({this.error});
  final String? error;
  @override
  State<_Address> createState() => _AddressState();
}

class _AddressState extends State<_Address> {
  final controller = TextEditingController(text: 'http://');
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConnectionSetupField(
    controller: controller,
    error: widget.error,
    onSubmitted: (_) {},
  );
}
