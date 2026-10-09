import {
  GroupedDialog,
  GroupedDialogNote,
} from "../GroupedDialog/GroupedDialog";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import type { AppleDevice, Platform } from "../../platform";

export interface NotificationsDialogProps {
  /** "Notify me": alerts when a reply finishes or Hermes needs the user. */
  enabled: boolean;
  /** The system refused notifications: while `enabled`, "Notify me" shows the warning "Turn on notifications for Hermes in system settings." */
  permissionDenied?: boolean;
  /** "Scheduled tasks": alerts when a cron job finishes or fails. Its switch is disabled while `enabled` is off. */
  scheduleAlerts: boolean;
  /** "Live Activities" (iPhone only). Leave out to hide the group, as on every device without them. */
  liveActivities?: boolean;
  /** iOS has Live Activities off for Hermes: the Live Activities row shows the warning "Turn on Live Activities for Hermes in system settings." */
  liveActivitiesBlocked?: boolean;
  onEnabledChange?: (on: boolean) => void;
  onScheduleAlertsChange?: (on: boolean) => void;
  onLiveActivitiesChange?: (on: boolean) => void;
  /** Done (Apple), or the barrier or Escape. */
  onDone?: () => void;
  /** Draw the dialog alone, without the dimmed barrier, for a catalog cell. */
  inline?: boolean;
  /** Follows `GroupedDialog`: Apple toggles (small on a Mac) or the Material switch. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
}

/**
 * The app's Notifications dialog (`showNotificationsDialog`): a
 * `GroupedDialog` with one switch per group and what it does as the group's
 * footer: "Notify me", "Scheduled tasks" and, on an iPhone, "Live
 * Activities"; then a note that alerts arrive only while Hermes is running.
 * A system refusal shows as a warning line under the switch's title.
 */
export function NotificationsDialog({
  enabled,
  permissionDenied = false,
  scheduleAlerts,
  liveActivities,
  liveActivitiesBlocked = false,
  onEnabledChange,
  onScheduleAlertsChange,
  onLiveActivitiesChange,
  onDone,
  inline,
  platform,
  device,
}: NotificationsDialogProps) {
  return (
    <GroupedDialog
      title="Notifications"
      onDone={onDone}
      inline={inline}
      platform={platform}
      device={device}
    >
      <GroupedSection footer="When a reply finishes or Hermes needs you, while the app is not in front. Replies show a preview; requests only say that Hermes is waiting.">
        <GroupedSwitchRow
          title="Notify me"
          warning={
            enabled && permissionDenied
              ? "Turn on notifications for Hermes in system settings."
              : undefined
          }
          checked={enabled}
          onChange={onEnabledChange}
        />
      </GroupedSection>
      <GroupedSection footer="When a scheduled task finishes or fails, while the app is open. Mute single tasks from their page.">
        <GroupedSwitchRow
          title="Scheduled tasks"
          checked={scheduleAlerts}
          disabled={!enabled}
          onChange={onScheduleAlertsChange}
        />
      </GroupedSection>
      {liveActivities !== undefined ? (
        <GroupedSection footer="Show a reply you sent on the Lock Screen and in the Dynamic Island while Hermes is running. It only says whether Hermes is working, waiting for you or done.">
          <GroupedSwitchRow
            title="Live Activities"
            warning={
              liveActivitiesBlocked
                ? "Turn on Live Activities for Hermes in system settings."
                : undefined
            }
            checked={liveActivities}
            onChange={onLiveActivitiesChange}
          />
        </GroupedSection>
      ) : null}
      <GroupedDialogNote>
        Alerts arrive while Hermes is running, including for a short time after
        you leave it.
      </GroupedDialogNote>
    </GroupedDialog>
  );
}
