import 'package:flutter/material.dart';

import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';

class McpSignInStatus extends StatelessWidget {
  const McpSignInStatus({
    super.key,
    required this.title,
    required this.detail,
    required this.waiting,
    required this.onClose,
    this.starting = false,
    this.onRetry,
    this.onOpenBrowser,
    this.onCopyAddress,
    this.address,
    this.addressRefused = false,
  });
  final String title, detail;
  final bool waiting, starting, addressRefused;
  final String? address;
  final VoidCallback? onClose, onRetry, onOpenBrowser, onCopyAddress;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GroupedSection(
        children: [
          GroupedRow(
            title: title,
            subtitle: detail,
            subtitleMaxLines: null,
            chevron: false,
            trailing: waiting || starting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : null,
          ),
        ],
      ),
      if (addressRefused)
        const GroupedFooter(
          'Hermes sent an address this app will not open, because it is '
          'not a web address. Cancel and try again, or check the server.',
          error: true,
        ),
      if (address != null) ...[
        const GroupedFooter(
          'Could not open the browser. Open this address yourself:',
        ),
        GroupedSection(
          children: [
            Padding(
              padding: EdgeInsets.all(GroupedMetrics.of(context).rowPadding),
              child: SelectableText(
                address!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: GroupedMetrics.of(context).footerSize,
                ),
              ),
            ),
            GroupedRow(
              title: 'Copy address',
              chevron: false,
              onTap: onCopyAddress,
            ),
          ],
        ),
      ],
      GroupedSection(
        children: [
          if (waiting)
            GroupedRow(
              title: 'Open the browser again',
              chevron: false,
              enabled: onOpenBrowser != null,
              onTap: onOpenBrowser,
            )
          else
            GroupedRow(
              title: 'Try again',
              chevron: false,
              enabled: !starting,
              onTap: starting ? null : onRetry,
            ),
          GroupedRow(
            title: waiting ? 'Cancel' : 'Close',
            chevron: false,
            enabled: !starting,
            onTap: starting ? null : onClose,
          ),
        ],
      ),
    ],
  );
}
