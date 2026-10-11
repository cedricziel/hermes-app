import 'package:flutter/material.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_banner.dart';
import 'package:hermes_app/src/mcp/mcp_command_review.dart';
import 'package:hermes_app/src/mcp/widgets/mcp_server_row.dart';
import 'package:hermes_app/src/mcp/widgets/mcp_credential_fields.dart';
import 'package:hermes_app/src/mcp/widgets/mcp_server_fields.dart';
import 'package:hermes_app/src/mcp/widgets/mcp_json_field.dart';
import 'package:hermes_app/src/mcp/widgets/mcp_sign_in_status.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookUseCase _banner(String name, McpBanner banner) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(banner));

const _grafana = HermesMcpServer(
  name: 'grafana',
  transport: McpTransport.remote,
  url: 'https://mcp.grafana.com/mcp',
  auth: 'oauth',
);

const _linear = HermesMcpServer(
  name: 'linear',
  transport: McpTransport.remote,
  url: 'https://mcp.linear.app/mcp',
  auth: 'oauth',
);

const _filesystem = HermesMcpServer(
  name: 'filesystem',
  transport: McpTransport.command,
  command: 'npx',
  args: ['-y', '@modelcontextprotocol/server-filesystem'],
  enabled: false,
);

const _docs = HermesMcpServer(
  name: 'docs',
  transport: McpTransport.remote,
  url: 'https://docs.example.test/mcp',
);

Widget _rows(BuildContext context) => GroupedListView(
  children: [
    GroupedSection(
      dividerIndent: GroupedMetrics.of(context).indentAfterTile,
      footer:
          'Changes apply from the next chat, not to one that is already '
          'running.',
      children: [
        McpServerRow(
          server: _grafana,
          tested: const HermesMcpTestResult(
            ok: true,
            tools: [
              HermesMcpTool(name: 'search_dashboards'),
              HermesMcpTool(name: 'query_prometheus'),
            ],
          ),
          selected: true,
          onTap: () {},
          onSwitch: (_) {},
        ),
        McpServerRow(
          server: _linear,
          tested: const HermesMcpTestResult(ok: false, signInNeeded: true),
          onTap: () {},
          onSwitch: (_) {},
        ),
        McpServerRow(server: _filesystem, onTap: () {}, onSwitch: (_) {}),
        McpServerRow(
          server: _docs,
          switching: true,
          onTap: () {},
          onSwitch: (_) {},
        ),
      ],
    ),
  ],
);

WidgetbookNode mcpNode() => WidgetbookFolder(
  name: 'MCP servers',
  children: [
    WidgetbookComponent(
      name: 'McpJsonField',
      useCases: [
        for (final readOnly in [false, true])
          ...onEachPlatform(
            readOnly ? 'Saving' : 'Editing',
            (_) => frame(_JsonExample(readOnly: readOnly), maxWidth: 600),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpSignInStatus',
      useCases: [
        for (final state in [
          'Waiting',
          'Browser failed',
          'Address refused',
          'Expired',
          'Failed',
          'Retrying',
        ])
          ...onEachPlatform(
            state,
            (_) => frame(
              McpSignInStatus(
                title:
                    state == 'Waiting' ||
                        state == 'Browser failed' ||
                        state == 'Address refused'
                    ? 'Waiting for you to approve'
                    : state == 'Expired'
                    ? 'The sign-in expired'
                    : 'Could not sign in',
                detail: state == 'Expired'
                    ? 'Hermes dropped it. Start it again to get a new link.'
                    : 'Approve the sign-in in your browser. It finishes on your Hermes server, so this screen closes by itself.',
                waiting: [
                  'Waiting',
                  'Browser failed',
                  'Address refused',
                ].contains(state),
                starting: state == 'Retrying',
                addressRefused: state == 'Address refused',
                address: state == 'Browser failed'
                    ? 'https://auth.example/authorize?state=example'
                    : null,
                onClose: () {},
                onRetry: () {},
                onCopyAddress: () {},
                onOpenBrowser: state == 'Address refused' ? null : () {},
              ),
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpServerFields',
      useCases: [
        for (final state in [
          'Remote',
          'Bearer token',
          'OAuth',
          'Command',
          'Invalid',
          'Saving',
        ])
          ...onEachPlatform(
            state,
            (_) => frame(_ServerExample(state: state), maxWidth: 560),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpCredentialFields',
      useCases: [
        for (final busy in [false, true])
          ...onEachPlatform(
            busy ? 'Installing' : 'Required and optional',
            (_) => frame(_CredentialExample(busy: busy)),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpServerRow',
      useCases: onEachPlatform(
        'Tested, sign-in needed, off and switching',
        _rows,
      ),
    ),
    WidgetbookComponent(
      name: 'McpBanner',
      useCases: [
        _banner(
          'Success',
          const McpBanner(
            tone: McpTone.success,
            icon: AppIcons.checkCircle,
            title: 'Connected',
            detail: 'Found 12 tools.',
          ),
        ),
        _banner(
          'Warning with action',
          McpBanner(
            tone: McpTone.warning,
            icon: AppIcons.lock,
            title: 'Sign-in needed',
            detail: 'Approve access in your browser.',
            action: TextButton(onPressed: () {}, child: const Text('Sign in')),
          ),
        ),
        _banner(
          'Error',
          const McpBanner(
            tone: McpTone.error,
            icon: AppIcons.error,
            title: 'Could not reach the server',
            detail: 'Connection refused',
          ),
        ),
        _banner(
          'Title only',
          const McpBanner(
            tone: McpTone.success,
            icon: AppIcons.checkCircle,
            title: 'Saved',
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpCommandReview',
      useCases: [
        WidgetbookUseCase(
          name: 'One command',
          builder: (_) => fill(
            const McpCommandReview(
              commands: [npxServer],
              confirmLabel: 'Add server',
            ),
            width: 480,
          ),
        ),
        WidgetbookUseCase(
          name: 'Several, with environment names',
          builder: (_) => fill(
            const McpCommandReview(
              commands: [npxServer, envServer],
              confirmLabel: 'Save servers',
            ),
            width: 480,
          ),
        ),
      ],
    ),
  ],
);

class _CredentialExample extends StatefulWidget {
  const _CredentialExample({required this.busy});
  final bool busy;
  @override
  State<_CredentialExample> createState() => _CredentialExampleState();
}

class _CredentialExampleState extends State<_CredentialExample> {
  final controllers = {
    'API_KEY': TextEditingController(),
    'WORKSPACE': TextEditingController(text: 'example'),
  };
  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => McpCredentialFields(
    credentials: const [
      HermesMcpCredential(name: 'API_KEY', prompt: 'Personal access token'),
      HermesMcpCredential(
        name: 'WORKSPACE',
        prompt: 'Workspace identifier',
        required: false,
      ),
    ],
    controllers: controllers,
    busy: widget.busy,
  );
}

class _ServerExample extends StatefulWidget {
  const _ServerExample({required this.state});
  final String state;
  @override
  State<_ServerExample> createState() => _ServerExampleState();
}

class _ServerExampleState extends State<_ServerExample> {
  final name = TextEditingController(text: 'example');
  final url = TextEditingController(text: 'https://mcp.example.com/mcp');
  final token = TextEditingController();
  final command = TextEditingController(text: 'npx');
  final args = TextEditingController(text: '-y\nexample-mcp');
  final envName = TextEditingController(text: 'API_KEY');
  final envValue = TextEditingController();
  @override
  void dispose() {
    for (final controller in [
      name,
      url,
      token,
      command,
      args,
      envName,
      envValue,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => McpServerFields(
    name: name,
    url: url,
    token: token,
    command: command,
    args: args,
    remote: widget.state != 'Command',
    saving: widget.state == 'Saving',
    auth: widget.state == 'Bearer token'
        ? McpRemoteAuth.bearerToken
        : widget.state == 'OAuth'
        ? McpRemoteAuth.oauth
        : McpRemoteAuth.none,
    nameError: widget.state == 'Invalid'
        ? 'A server with this name already exists'
        : null,
    onRemoteChanged: (_) {},
    onAuthChanged: (_) {},
    onNameChanged: (_) {},
    onSubmit: () {},
    onAddVariable: () {},
    environment: [
      McpEnvironmentField(name: envName, value: envValue, onRemove: () {}),
    ],
  );
}

class _JsonExample extends StatefulWidget {
  const _JsonExample({required this.readOnly});
  final bool readOnly;
  @override
  State<_JsonExample> createState() => _JsonExampleState();
}

class _JsonExampleState extends State<_JsonExample> {
  final controller = TextEditingController(
    text: '{\n  "example": {\n    "url": "https://mcp.example.com/mcp"\n  }\n}',
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 320,
    child: McpJsonField(controller: controller, readOnly: widget.readOnly),
  );
}
