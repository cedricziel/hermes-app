import {
  GroupedDialog,
  GroupedDialogNote,
} from "../GroupedDialog/GroupedDialog";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import type { AppleDevice, Platform } from "../../platform";

export interface AppLockDialogProps {
  /** App lock is on: Hermes asks for Face ID, Touch ID or the passcode when opened. */
  enabled: boolean;
  /**
   * The device offers Face ID, Touch ID, a fingerprint or a passcode. When
   * false the switch is disabled (unless app lock is still on, so it can be
   * turned off) and a note says to set one up in system settings.
   */
  available?: boolean;
  onChange?: (on: boolean) => void;
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
 * The app's App lock dialog (`showAppLockDialog`): a `GroupedDialog` titled
 * "App lock" with the switch "Require Face ID or Touch ID", what it does as
 * the group's footer, and, on a device without biometrics or a passcode, a
 * note after the group while the switch is greyed out.
 */
export function AppLockDialog({
  enabled,
  available = true,
  onChange,
  onDone,
  inline,
  platform,
  device,
}: AppLockDialogProps) {
  return (
    <GroupedDialog
      title="App lock"
      onDone={onDone}
      inline={inline}
      platform={platform}
      device={device}
    >
      <GroupedSection footer="Hermes asks for Face ID, Touch ID, fingerprint or your device passcode when you open it and when you come back to it.">
        <GroupedSwitchRow
          title="Require Face ID or Touch ID"
          checked={enabled}
          disabled={!available && !enabled}
          onChange={onChange}
        />
      </GroupedSection>
      {available ? null : (
        <GroupedDialogNote>
          Set up Face ID, Touch ID or a passcode in system settings to use app
          lock. This device does not offer one right now.
        </GroupedDialogNote>
      )}
    </GroupedDialog>
  );
}
