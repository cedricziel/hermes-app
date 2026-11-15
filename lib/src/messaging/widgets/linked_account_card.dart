import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/grouped_list.dart';

/// A name longer than this goes under its title and wraps, instead of sitting
/// at the row's trailing edge where half a row would cut it.
const kLinkedNameInlineLength = 18;

/// The linked account: a success banner "WhatsApp is linked." (or, when the
/// server already had it, a neutral "Already linked" that says the app cannot
/// unlink or replace it), and the account as two rows, Name and Number.
///
/// A missing name reads "Name not given", a missing number "Number not
/// given". The number is the digits the server gave with a leading `+` and is
/// never cut: above the default text size the value stacks under its title.
/// A long name moves under the title and wraps. Name and number are the
/// user's own data, shown here only (no log, no snapshot); control and bidi
/// characters in the name are drawn visibly.
class LinkedAccountCard extends StatelessWidget {
  const LinkedAccountCard({
    super.key,
    required this.alreadyLinked,
    this.name,
    this.phone,
  });

  final bool alreadyLinked;
  final String? name;

  /// The digits of the account's number, without the `+`.
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shownName = _blank(name) ? null : safePathText(name!.trim());
    final shownPhone = _blank(phone) ? null : '+${phone!.trim()}';
    final nameInline =
        shownName != null && shownName.length <= kLinkedNameInlineLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (alreadyLinked)
          AppBanner(
            tone: AppBannerTone.neutral,
            title: l10n.messagingWhatsappAlreadyLinkedTitle,
            detail: l10n.messagingWhatsappAlreadyLinkedDetail,
          )
        else
          AppBanner(
            tone: AppBannerTone.success,
            title: l10n.messagingWhatsappLinkedTitle,
          ),
        GroupedSection(
          header: l10n.messagingWhatsappAccountHeader,
          children: [
            GroupedRow(
              title: l10n.messagingWhatsappAccountName,
              value: nameInline ? shownName : null,
              subtitle: nameInline
                  ? null
                  : (shownName ?? l10n.messagingWhatsappNameMissing),
              subtitleMaxLines: null,
              wrapWhenStacked: true,
            ),
            GroupedRow(
              title: l10n.messagingWhatsappAccountNumber,
              value: shownPhone,
              subtitle: shownPhone == null
                  ? l10n.messagingWhatsappNumberMissing
                  : null,
              subtitleMaxLines: null,
              wrapWhenStacked: true,
            ),
          ],
        ),
      ],
    );
  }

  static bool _blank(String? text) => text == null || text.trim().isEmpty;
}
