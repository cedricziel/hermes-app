import { Button } from "../Button/Button";
import { Spinner } from "../Spinner/Spinner";
import { TextField } from "../TextField/TextField";
import { ScreenFrame, type ScreenLayout } from "../../screenFrame";
import type { AppleDevice, Platform } from "../../platform";
import "./TelegramPairingScreen.css";

/** Where pairing a Telegram bot stands. */
export type TelegramPairingPhase =
  "starting" | "waiting" | "claimed" | "failed";

export interface TelegramPairingScreenProps {
  /**
   * `starting`: Hermes asks its setup service for a bot (a spinner).
   * `waiting`: the link to open in Telegram, Open Telegram and Copy link,
   * and "Waiting for you in Telegram". `claimed`: the bot is ready; the
   * allowed user IDs field and Finish setup. `failed`: the error and Start
   * again.
   */
  phase: TelegramPairingPhase;
  /** The `t.me` link that claims the bot (`waiting`). */
  link?: string;
  /** The new bot's username without "@" (`claimed`): "hermes_work_bot". */
  botUsername?: string;
  /** The allowed Telegram user IDs, comma-separated (`claimed`). Prefilled with the owner's ID when Telegram reported it. */
  userIds?: string;
  /** Validation message under the IDs field: "Add at least one Telegram user ID". */
  userIdsError?: string;
  /** Why it failed (`failed`), or why Finish setup failed (`claimed`), in red. */
  error?: string;
  /** Finish setup is in flight: the button is disabled. */
  saving?: boolean;
  onBack?: () => void;
  onOpenTelegram?: () => void;
  onCopyLink?: () => void;
  onUserIdsChange?: (value: string) => void;
  onFinish?: () => void;
  onStartAgain?: () => void;
  /** `phone` or `desktop`; the content stays in a 640px column. */
  layout?: ScreenLayout;
  /** `apple`: chevron back with "Messaging", Apple spinners. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * Pairs a Telegram bot without making one by hand, pushed from Messaging setup's
 * "Set up with Telegram": the user opens a link in Telegram to claim a bot
 * Hermes had made, then says which Telegram accounts may talk to it. The
 * bot's token never reaches the app. Built from `ListDetailLayout`,
 * `Button`, `TextField` and `Spinner`.
 */
export function TelegramPairingScreen({
  phase,
  link = "",
  botUsername,
  userIds = "",
  userIdsError,
  error,
  saving = false,
  onBack,
  onOpenTelegram,
  onCopyLink,
  onUserIdsChange,
  onFinish,
  onStartAgain,
  layout = "phone",
  platform,
  device,
}: TelegramPairingScreenProps) {
  const errorText = error ? (
    <div className="h-body-md h-pairing__error" role="alert">
      {error}
    </div>
  ) : null;
  return (
    <ScreenFrame
      title="Set up with Telegram"
      onBack={onBack}
      backLabel="Messaging"
      layout={layout}
      platform={platform}
      device={device}
    >
      <div className="h-pairing">
        {phase === "starting" ? (
          <div className="h-pairing__center">
            <Spinner size={36} label="Starting" />
          </div>
        ) : null}
        {phase === "waiting" ? (
          <>
            <div className="h-body-md">
              Open this link on a device with Telegram and tap Start. Hermes
              gets a new bot that only you can use.
            </div>
            <div className="h-body-md h-pairing__link">{link}</div>
            <div className="h-pairing__buttons">
              <Button icon="send" onClick={onOpenTelegram}>
                Open Telegram
              </Button>
              <Button
                variant="outlined"
                icon="content_copy"
                onClick={onCopyLink}
              >
                Copy link
              </Button>
            </div>
            <div className="h-body-md h-pairing__waiting">
              <Spinner size={16} label="Waiting" />
              <span>Waiting for you in Telegram</span>
            </div>
          </>
        ) : null}
        {phase === "claimed" ? (
          <>
            <div className="h-body-md">
              {botUsername
                ? `Your bot @${botUsername} is ready. Which Telegram accounts may talk to it?`
                : "Your bot is ready."}
            </div>
            <TextField
              label="Allowed Telegram user IDs"
              inputMode="numeric"
              value={userIds}
              error={userIdsError}
              helper="Comma-separated numeric IDs. Yours is filled in if Telegram reported it."
              onChange={(e) => onUserIdsChange?.(e.target.value)}
            />
            {errorText}
            <Button fullWidth disabled={saving} onClick={onFinish}>
              Finish setup
            </Button>
          </>
        ) : null}
        {phase === "failed" ? (
          <>
            {errorText}
            <Button fullWidth onClick={onStartAgain}>
              Start again
            </Button>
          </>
        ) : null}
      </div>
    </ScreenFrame>
  );
}
