import { ListRow } from "../ListRow/ListRow";
import { Switch } from "../Switch/Switch";
import type { Platform } from "../../platform";

/** A messaging platform Hermes can run as a bot. */
export interface Bot {
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

export interface BotRowProps {
  /** The platform to show. */
  bot: Bot;
  /** The row was pressed: open its setup. */
  onClick?: () => void;
  /** The switch was flipped to this value. */
  onEnabledChange?: (enabled: boolean) => void;
  /** `apple`: the iOS row and the 51x31 toggle. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * One platform on the Bots screen: a bot icon, the name, a subtitle of its
 * description, "Needs setup" and the last error, and an enabled switch that
 * is disabled while the bot is off and not set up. Built on `ListRow` as a
 * plain, full-width row on every platform, as the app draws it.
 */
export function BotRow({
  bot,
  onClick,
  onEnabledChange,
  platform,
}: BotRowProps) {
  const subtitle = [
    bot.description,
    bot.configured ? undefined : "Needs setup",
    bot.errorMessage,
  ]
    .filter(Boolean)
    .join(" · ");
  return (
    <ListRow
      platform={platform}
      grouped={false}
      icon="smart_toy"
      title={bot.name}
      subtitle={subtitle || undefined}
      onClick={onClick}
      trailing={
        <Switch
          checked={bot.enabled}
          label={`${bot.name} enabled`}
          disabled={!bot.configured && !bot.enabled}
          onChange={onEnabledChange}
        />
      }
    />
  );
}
