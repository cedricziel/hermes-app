import { useEffect, useState } from "react";
import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { Spinner } from "../Spinner/Spinner";
import {
  cx,
  PlatformScope,
  useRowDevice,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./BotScreenCard.css";

/** One state of the card; the app shows exactly one, chosen in this order. */
export type BotScreenCardState =
  | "not_offered"
  | "not_installed"
  | "blocked"
  | "starting"
  | "off"
  | "error"
  | "frame"
  | "controlled";

/** Why the last Start Screen failed. */
export type BotScreenStartFailure = "display" | "timeout" | "closed";

export interface BotScreenCardProps {
  /**
   * What the card shows. `not_offered`: the server uses its own display, no
   * action. `not_installed`: the desktop packages are missing (see `command`,
   * `sandbox`). `blocked`: the screen cannot start (`blockerText`,
   * `memoryMb`). `starting`: a Start Screen request is in flight. `off`: the
   * screen is stopped, with Start Screen (`startFailure` after a failed
   * start). `error`: "Couldn't read the screen" with Try Again. `frame`:
   * Hermes holds control and the latest picture is shown (`frameSrc`, or
   * "Waiting for the first picture…" without it). `controlled`: a person
   * holds control, so there is no picture (`byYou`).
   */
  state: BotScreenCardState;
  /** `not_installed` on the server itself: the install command to copy, drawn in monospace with Copy. Leave out when the server sent none. */
  command?: string;
  /** `not_installed` for a profile whose screen lives in the terminal sandbox: says the sandbox image needs the desktop stack, and never shows a command. */
  sandbox?: boolean;
  /** `blocked`: the server's own words. */
  blockerText?: string;
  /** `blocked`: free memory in MB, shown only when the server reports it. */
  memoryMb?: number;
  /** `off`: why the last start failed; adds "Couldn't start the screen." and a reason. */
  startFailure?: BotScreenStartFailure;
  /** `frame`: the latest picture, an image URL or data URL. */
  frameSrc?: string;
  /** `frame`: width over height of the screen, from its geometry, kept between 0.5 and 3 as the app does; default 16 / 10. */
  aspectRatio?: number;
  /** `controlled`: true says "You're in control", otherwise "Someone else is in control". */
  byYou?: boolean;
  /** Start Screen, in `off`; hidden without it. */
  onStart?: () => void;
  /** Copy, in `not_installed`; hidden without it. */
  onCopyCommand?: () => void;
  /** Try Again, in `error`; hidden without it. */
  onRetry?: () => void;
  /** Enlarge, over a `frame`. Leave it out: the app shows no Enlarge until the live viewer it opens exists. */
  onEnlarge?: () => void;
  /** Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`: `touch` (default, iPhone and iPad) keeps the buttons at least 44px tall, `mac` leaves them at their own height. Ignored on `material`. */
  device?: AppleDevice;
}

const failureText: Record<BotScreenStartFailure, string> = {
  display: "Hermes could not start it.",
  timeout: "Hermes did not answer in time.",
  closed: "The connection closed first.",
};

/**
 * The Bot screen card of the Activity panel, listed under Now: what the
 * agent's own Linux desktop shows, who is in control, and why there is no
 * picture when there is none. The app lists it while the chat's profile has a
 * running screen, or while it has none and the chat used `computer_use`; it
 * refreshes the picture every 3 seconds only while the panel shows it. A
 * 14px-radius outlined box with a "Bot screen" title row and one state below.
 * Start Screen and Try Again are filled buttons, as the app's tonal buttons
 * draw. The layout is the same on every platform; the icons follow `platform`
 * and, on iPhone and iPad, the buttons are at least 44px tall (`device`).
 */
export function BotScreenCard({
  state,
  command,
  sandbox = false,
  blockerText,
  memoryMb,
  startFailure,
  frameSrc,
  aspectRatio = 16 / 10,
  byYou = false,
  onStart,
  onCopyCommand,
  onRetry,
  onEnlarge,
  platform,
  device,
}: BotScreenCardProps) {
  const resolved = usePlatform(platform);
  const appleDevice = useRowDevice(device);
  const touch = resolved === "apple" && appleDevice === "touch";
  const [copied, setCopied] = useState(false);
  useEffect(() => {
    if (!copied) return;
    const timer = setTimeout(() => setCopied(false), 2000);
    return () => clearTimeout(timer);
  }, [copied]);
  return (
    <PlatformScope platform={resolved}>
      <section
        className={cx("h-bot-screen", touch && "h-bot-screen--touch")}
        aria-label="Bot screen"
      >
        <div className="h-bot-screen__title">
          <Icon name="desktop_windows_outlined" size={18} />
          <h3>Bot screen</h3>
        </div>
        {state === "not_offered" ? (
          <p>Hermes uses this server's own display.</p>
        ) : null}
        {state === "not_installed" && sandbox ? (
          <p>
            This profile's terminal runs in a sandbox, and its sandbox image
            needs the desktop stack.
          </p>
        ) : null}
        {state === "not_installed" && !sandbox ? (
          <>
            <p>
              {command
                ? "The desktop isn't installed on the server. Run this there:"
                : "The desktop isn't installed on the server."}
            </p>
            {command ? (
              <>
                <code className="h-bot-screen__command">{command}</code>
                {onCopyCommand ? (
                  <div className="h-bot-screen__action">
                    <Button
                      variant="text"
                      compact
                      icon={copied ? "check" : "copy"}
                      aria-label={copied ? "Copied" : "Copy install command"}
                      onClick={() => {
                        onCopyCommand();
                        setCopied(true);
                      }}
                    >
                      {copied ? "Copied" : "Copy"}
                    </Button>
                  </div>
                ) : null}
              </>
            ) : null}
          </>
        ) : null}
        {state === "blocked" ? (
          <div className="h-bot-screen__blocked">
            <Icon name="warning_amber_outlined" size={20} />
            <div>
              <div>{blockerText}</div>
              {memoryMb !== undefined ? (
                <div className="h-bot-screen__caption">
                  {memoryMb} MB of memory available
                </div>
              ) : null}
            </div>
          </div>
        ) : null}
        {state === "starting" ? (
          <div className="h-bot-screen__starting">
            <Spinner size={16} label="Starting the screen" />
            <span>Starting the screen…</span>
          </div>
        ) : null}
        {state === "off" ? (
          <>
            {startFailure ? (
              <div>
                <div className="h-bot-screen__failed">
                  Couldn't start the screen.
                </div>
                <div>{failureText[startFailure]}</div>
              </div>
            ) : null}
            <p>The screen is off. It starts by itself when Hermes needs it.</p>
            {onStart ? (
              <div className="h-bot-screen__action">
                <Button variant="filled" onClick={onStart}>
                  Start Screen
                </Button>
              </div>
            ) : null}
          </>
        ) : null}
        {state === "error" ? (
          <>
            <p>Couldn't read the screen</p>
            {onRetry ? (
              <div className="h-bot-screen__action">
                <Button variant="filled" onClick={onRetry}>
                  Try Again
                </Button>
              </div>
            ) : null}
          </>
        ) : null}
        {state === "frame" ? (
          <>
            <div
              className="h-bot-screen__picture"
              style={{
                aspectRatio: String(Math.min(3, Math.max(0.5, aspectRatio))),
              }}
            >
              {frameSrc ? (
                <img src={frameSrc} alt="Hermes's screen" />
              ) : (
                <span className="h-bot-screen__caption">
                  Waiting for the first picture…
                </span>
              )}
              {onEnlarge ? (
                <IconButton
                  className="h-bot-screen__enlarge"
                  icon="open_in_full"
                  label="Enlarge screen"
                  size={32}
                  onClick={onEnlarge}
                />
              ) : null}
            </div>
            <div className="h-bot-screen__caption">Hermes is in control</div>
          </>
        ) : null}
        {state === "controlled" ? (
          <div className="h-bot-screen__controlled">
            <Icon name="lock_outline" size={18} />
            <span>
              {byYou ? "You're in control" : "Someone else is in control"}
            </span>
          </div>
        ) : null}
      </section>
    </PlatformScope>
  );
}
