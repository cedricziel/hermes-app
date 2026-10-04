import { BotRow, type Bot } from "../BotRow/BotRow";
import { Button } from "../Button/Button";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import { ScreenFrame, type ScreenLayout } from "../../screenFrame";
import { usePlatform, type AppleDevice, type Platform } from "../../platform";

export interface BotsScreenProps {
  /** The messaging platforms the dashboard knows, in its order. */
  bots?: Bot[];
  /** `loaded` (default), `loading` (a spinner) or `failed` ("Could not load bots" with Retry). */
  state?: "loaded" | "loading" | "failed";
  /** A row was pressed: open its setup (`BotSetupScreen`). */
  onOpen?: (id: string) => void;
  /** A bot's switch was flipped. */
  onEnabledChange?: (id: string, enabled: boolean) => void;
  onRetry?: () => void;
  /** Back to the chat ("Chat" beside the iOS chevron). */
  onBack?: () => void;
  /** `phone` or `desktop` (a Mac window or a Material desktop, the rows in a centred 640px column). */
  layout?: ScreenLayout;
  /** `apple`: chevron back, 44px bar (52px on a Mac), iOS rows and toggles. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * The Bots screen, pushed from the chat sidebar: the messaging platforms
 * Hermes can run as bots (Telegram, Discord, Slack...) as `BotRow`s with an
 * enabled switch. A platform without credentials says "Needs setup" and
 * can't be switched on until its row is opened and set up.
 */
export function BotsScreen({
  bots = [],
  state = "loaded",
  onOpen,
  onEnabledChange,
  onRetry,
  onBack,
  layout = "phone",
  platform,
  device,
}: BotsScreenProps) {
  const resolved = usePlatform(platform);
  return (
    <ScreenFrame
      title="Bots"
      onBack={onBack}
      backLabel="Chat"
      layout={layout}
      platform={resolved}
      device={device}
      centered={state !== "loaded"}
    >
      {state === "loading" ? <Spinner size={36} label="Loading bots" /> : null}
      {state === "failed" ? (
        <StateMessage
          title="Could not load bots"
          action={<Button onClick={onRetry}>Retry</Button>}
        />
      ) : null}
      {state === "loaded"
        ? bots.map((bot) => (
            <BotRow
              key={bot.id}
              bot={bot}
              onClick={() => onOpen?.(bot.id)}
              onEnabledChange={(v) => onEnabledChange?.(bot.id, v)}
            />
          ))
        : null}
    </ScreenFrame>
  );
}
