import { Button } from "../Button/Button";
import { GroupedRow, GroupedTile } from "../GroupedRow/GroupedRow";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import {
  cx,
  useGroupedChrome,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./MessagingPlatformRow.css";

/** A messaging platform Hermes can connect to (Telegram, Discord, Slack...). */
export interface MessagingPlatform {
  /** Platform id: "telegram", "discord", "slack". */
  id: string;
  /** Display name: "Telegram". */
  name: string;
  /** What it does: "Run Hermes from Telegram." */
  description?: string;
  /** Switched on on the server. */
  enabled: boolean;
  /** Its credentials are saved. While it is neither configured nor enabled the row offers "Set Up" instead of a switch; enabled without credentials it warns "Needs setup". */
  configured: boolean;
  /** What went wrong when it last ran: "Invalid bot token". Drawn in the error color with an error glyph. */
  errorMessage?: string;
}

export interface MessagingPlatformRowProps {
  /** The platform to show. */
  messagingPlatform: MessagingPlatform;
  /** The row (or its Set Up button) was pressed: open its setup. */
  onClick?: () => void;
  /** The switch was flipped to this value. */
  onEnabledChange?: (enabled: boolean) => void;
  /** `apple` or `material`. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`: `mac` (40px row, 24px tile, small switch, "Set Up…" button) or `touch`. Inherited from the enclosing `GroupedSection` or `SettingsScaffold`. */
  device?: AppleDevice;
}

/**
 * One platform in the Messaging screen's `GroupedSection` (with
 * `dividerIndent="tile"`): the bot icon in a `GroupedTile`, the name, the
 * description as a one-line muted subtitle, and the last error in the error
 * color with an error glyph. A configured or enabled platform ends in its
 * switch; enabled without credentials it adds a "Needs setup" warning line.
 * A platform that is off and has no credentials offers Set Up instead: iOS
 * a muted "Set Up" value and chevron, Material an outlined pill button "Set
 * up" (14px semibold), Mac a small bordered button "Set Up…" (12px, 6px
 * corners). The row opens the platform's setup.
 */
export function MessagingPlatformRow({
  messagingPlatform: p,
  onClick,
  onEnabledChange,
  platform,
  device,
}: MessagingPlatformRowProps) {
  const chrome = useGroupedChrome(platform, device);
  const shared = {
    title: p.name,
    subtitle: p.description,
    error: p.errorMessage,
    leading: (
      <GroupedTile icon="smart_toy" platform={platform} device={device} />
    ),
    onClick,
    platform,
    device,
  };
  if (p.configured || p.enabled) {
    return (
      <GroupedSwitchRow
        {...shared}
        warning={p.configured ? undefined : "Needs setup"}
        checked={p.enabled}
        onChange={onEnabledChange}
      />
    );
  }
  if (chrome === "ios")
    return <GroupedRow {...shared} value="Set Up" chevron />;
  const mac = chrome === "mac";
  return (
    <GroupedRow
      {...shared}
      trailing={
        <Button
          variant="outlined"
          compact
          className={cx(
            "h-messaging-row__setup",
            mac && "h-messaging-row__setup--mac",
          )}
          onClick={onClick}
        >
          {mac ? "Set Up…" : "Set up"}
        </Button>
      }
    />
  );
}
