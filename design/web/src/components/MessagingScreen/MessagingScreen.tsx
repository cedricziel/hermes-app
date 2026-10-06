import { Button } from "../Button/Button";
import {
  MessagingPlatformRow,
  type MessagingPlatform,
} from "../MessagingPlatformRow/MessagingPlatformRow";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import { ScreenFrame, type ScreenLayout } from "../../screenFrame";
import type { AppleDevice, Platform } from "../../platform";
import "./MessagingScreen.css";

export interface MessagingScreenProps {
  /** The messaging platforms the dashboard knows, in its order. */
  platforms?: MessagingPlatform[];
  /** `loaded` (default), `loading` (a spinner) or `failed` ("Could not load messaging platforms" with Retry). The introduction stays above either. */
  state?: "loaded" | "loading" | "failed";
  /** A row was pressed: open its setup (`MessagingSetupScreen`). */
  onOpen?: (id: string) => void;
  /** A platform's switch was flipped. */
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
 * The Messaging screen, pushed from the chat sidebar: a line on what it is
 * for, then the messaging platforms Hermes can connect to (Telegram,
 * Discord, Slack...) as `MessagingPlatformRow`s with an enabled switch. A
 * platform without credentials says "Needs setup" and can't be switched on
 * until its row is opened and set up.
 */
export function MessagingScreen({
  platforms = [],
  state = "loaded",
  onOpen,
  onEnabledChange,
  onRetry,
  onBack,
  layout = "phone",
  platform,
  device,
}: MessagingScreenProps) {
  return (
    <ScreenFrame
      title="Messaging"
      onBack={onBack}
      backLabel="Chat"
      layout={layout}
      platform={platform}
      device={device}
    >
      <div className="h-messaging">
        <div className="h-body-md h-messaging__intro">
          Connect Hermes to Telegram, Discord, and other messaging platforms.
        </div>
        {state === "loaded" ? (
          platforms.map((p) => (
            <MessagingPlatformRow
              key={p.id}
              messagingPlatform={p}
              onClick={() => onOpen?.(p.id)}
              onEnabledChange={(v) => onEnabledChange?.(p.id, v)}
            />
          ))
        ) : (
          <div className="h-messaging__state">
            {state === "loading" ? (
              <Spinner size={36} label="Loading messaging platforms" />
            ) : (
              <StateMessage
                title="Could not load messaging platforms"
                action={<Button onClick={onRetry}>Retry</Button>}
              />
            )}
          </div>
        )}
      </div>
    </ScreenFrame>
  );
}
