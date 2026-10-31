import 'package:flutter/widgets.dart';

/// Sent up the tree when the reader opens or closes a disclosure (a tool
/// group, a reasoning block, a tool call's details), just before it changes
/// size.
///
/// A list that keeps itself scrolled to the end (the chat transcript) uses it
/// to keep the disclosure's header where the reader tapped it, instead of
/// jumping to the new end and carrying the header out of view.
class DisclosureToggledNotification extends Notification {
  const DisclosureToggledNotification(this.context);

  /// The disclosure that was toggled; its top edge is its header.
  final BuildContext context;

  /// Sends the notification from [context], about the disclosure there.
  static void send(BuildContext context) =>
      DisclosureToggledNotification(context).dispatch(context);
}
