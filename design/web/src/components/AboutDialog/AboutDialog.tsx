import { GroupedDialog } from "../GroupedDialog/GroupedDialog";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import type { AppleDevice, Platform } from "../../platform";

export interface AboutDialogProps {
  /** The app's version, "0.1.55", or "Unavailable" when it cannot be read. */
  version: string;
  /** "Report a bug": the app opens its issue tracker in the browser. */
  onReportBug?: () => void;
  /** Done (Apple), or the barrier or Escape. */
  onDone?: () => void;
  /** Draw the dialog alone, without the dimmed barrier, for a catalog cell. */
  inline?: boolean;
  /** Follows `GroupedDialog`. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
}

/**
 * The app's About dialog (`AppAboutDialog`): a `GroupedDialog` titled
 * "About" with one group, Version (the number as a muted value) and "Report
 * a bug" (a chevron row).
 */
export function AboutDialog({
  version,
  onReportBug,
  onDone,
  inline,
  platform,
  device,
}: AboutDialogProps) {
  return (
    <GroupedDialog
      title="About"
      onDone={onDone}
      inline={inline}
      platform={platform}
      device={device}
    >
      <GroupedSection>
        <GroupedRow title="Version" value={version} />
        <GroupedRow title="Report a bug" onClick={onReportBug} />
      </GroupedSection>
    </GroupedDialog>
  );
}
