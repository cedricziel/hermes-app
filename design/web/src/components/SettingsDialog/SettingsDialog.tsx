import { GroupedDialog } from "../GroupedDialog/GroupedDialog";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import type { AppleDevice, Platform } from "../../platform";

/** An entry of the Settings list: each opens its own dialog, except `change-server`, which leaves for the server setup screen. */
export type SettingsEntry =
  "appearance" | "notifications" | "app-lock" | "about" | "change-server";

export interface SettingsDialogProps {
  /** The theme the Appearance row shows as its value: "Follow system", "Light" or "Dark". Leave out for no value. */
  appearance?: string;
  /** Notifications are on: the Notifications row reads "On", else "Off". Leave out for no value. */
  notifications?: boolean;
  /** App lock is on: the App Lock row reads "On", else "Off". Leave out for no value. */
  appLock?: boolean;
  /** A row was picked; the app closes this list and opens that entry's dialog. */
  onPick?: (entry: SettingsEntry) => void;
  /** Done (Apple), or the barrier or Escape. */
  onDone?: () => void;
  /** Draw the dialog alone, without the dimmed barrier, for a catalog cell. */
  inline?: boolean;
  /**
   * The app opens this list from the Mac account menu's Settings… (⌘,), so
   * `apple` + `mac` is its usual look: a 460px panel, a 44px bar with
   * "Settings" in 13px bold and Done, 40px rows with the value muted before
   * a chevron. `apple` + `touch` and `material` follow `GroupedDialog`.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
}

const onOff = (on: boolean | undefined) =>
  on === undefined ? undefined : on ? "On" : "Off";

/**
 * The app's Settings list (`showSettingsDialog`): a `GroupedDialog` titled
 * "Settings" with two groups of chevron rows. Appearance (the theme),
 * Notifications and App Lock (On/Off) show their current value; About
 * Hermes and Change Server have none. Covers its nearest positioned
 * ancestor with a dimmed barrier unless `inline`.
 */
export function SettingsDialog({
  appearance,
  notifications,
  appLock,
  onPick,
  onDone,
  inline,
  platform,
  device,
}: SettingsDialogProps) {
  const row = (entry: SettingsEntry, title: string, value?: string) => (
    <GroupedRow title={title} value={value} onClick={() => onPick?.(entry)} />
  );
  return (
    <GroupedDialog
      title="Settings"
      onDone={onDone}
      inline={inline}
      platform={platform}
      device={device}
    >
      <GroupedSection>
        {row("appearance", "Appearance", appearance)}
        {row("notifications", "Notifications", onOff(notifications))}
        {row("app-lock", "App Lock", onOff(appLock))}
      </GroupedSection>
      <GroupedSection>
        {row("about", "About Hermes")}
        {row("change-server", "Change Server")}
      </GroupedSection>
    </GroupedDialog>
  );
}
