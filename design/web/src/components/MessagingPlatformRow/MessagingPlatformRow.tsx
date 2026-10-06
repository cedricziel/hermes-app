import { ListRow } from "../ListRow/ListRow";
import { Switch } from "../Switch/Switch";
import type { Platform } from "../../platform";

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
  /** Its credentials are saved. Without them the row says "Needs setup" and the switch is off limits until the row is opened and set up. */
  configured: boolean;
  /** What went wrong when it last ran: "Invalid bot token". */
  errorMessage?: string;
}

export interface MessagingPlatformRowProps {
  /** The platform to show. */
  messagingPlatform: MessagingPlatform;
  /** The row was pressed: open its setup. */
  onClick?: () => void;
  /** The switch was flipped to this value. */
  onEnabledChange?: (enabled: boolean) => void;
  /** `apple`: the iOS row and the 51x31 toggle. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * One platform on the Messaging screen: a bot icon, the name, a subtitle of
 * its description, "Needs setup" and the last error, and an enabled switch
 * that is disabled while the platform is off and not set up. Built on
 * `ListRow` as a plain, full-width row on every platform, as the app draws it.
 */
export function MessagingPlatformRow({
  messagingPlatform: p,
  onClick,
  onEnabledChange,
  platform,
}: MessagingPlatformRowProps) {
  const subtitle = [
    p.description,
    p.configured ? undefined : "Needs setup",
    p.errorMessage,
  ]
    .filter(Boolean)
    .join(" · ");
  return (
    <ListRow
      platform={platform}
      grouped={false}
      icon="smart_toy"
      title={p.name}
      subtitle={subtitle || undefined}
      onClick={onClick}
      trailing={
        <Switch
          checked={p.enabled}
          label={`${p.name} enabled`}
          disabled={!p.configured && !p.enabled}
          onChange={onEnabledChange}
        />
      }
    />
  );
}
