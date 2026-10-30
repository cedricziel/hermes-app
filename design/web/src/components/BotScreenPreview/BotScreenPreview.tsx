import { Icon } from "../Icon/Icon";
import { cx } from "../../platform";
import "./BotScreenPreview.css";

/** What the preview shows: Hermes holds control (the picture, or a wait for the first one), or a person does (no picture). */
export type BotScreenPreviewState = "frame" | "controlled";

export interface BotScreenPreviewProps {
  /** `frame`: the latest picture with a Live badge and "Hermes is in control". `controlled`: a person holds control, so there is no picture, only who. */
  state?: BotScreenPreviewState;
  /** `frame`: the latest picture, an image URL or data URL. Without it the box says "Waiting for the first picture…". */
  frameSrc?: string;
  /** `frame`: width over height of the screen, kept between 0.5 and 3 as the app does; default 16 / 10. */
  aspectRatio?: number;
  /** `controlled`: true says "You're in control", otherwise "Someone else is in control". */
  byYou?: boolean;
  /** Makes the preview a button. In the app a tap opens the live viewer (`BotScreenViewer`). */
  onOpen?: () => void;
  className?: string;
}

const MAX_WIDTH = 320;
const MAX_HEIGHT = 200;

/**
 * The still preview of the bot's screen under a `computer_use` tool call, at most 320px wide
 * and 200px tall: the latest picture in an outlined box, a Live badge top left, and "Hermes is
 * in control" under it. The app draws it for as long as the reply is using the screen, in the
 * `preview` slot of a ToolCallGroup, right under the card of a single call or under the line
 * of a folded group, outside any card; it refreshes about every 3 seconds, only while it is on screen. When a person
 * holds control it shrinks to one outlined line with a lock.
 */
export function BotScreenPreview({
  state = "frame",
  frameSrc,
  aspectRatio = 16 / 10,
  byYou = false,
  onOpen,
  className,
}: BotScreenPreviewProps) {
  const ratio = Math.min(3, Math.max(0.5, aspectRatio));
  // What assistive technology hears for the picture or the pill, as in the app.
  const label =
    state === "controlled"
      ? `Hermes's screen. ${byYou ? "You're in control" : "Someone else is in control"}`
      : "Hermes's screen, live. Hermes is in control";
  const body =
    state === "controlled" ? (
      <span className="h-bot-preview__controlled">
        <Icon name="lock_outline" size={16} />
        <span>
          {byYou ? "You're in control" : "Someone else is in control"}
        </span>
      </span>
    ) : (
      <span
        className="h-bot-preview__picture"
        style={{ aspectRatio: String(ratio) }}
      >
        {frameSrc ? (
          <img src={frameSrc} alt="Hermes's screen" />
        ) : (
          <span className="h-bot-preview__caption">
            Waiting for the first picture…
          </span>
        )}
        <span className="h-bot-preview__live">
          <span className="h-bot-preview__dot" />
          Live
        </span>
      </span>
    );
  const wrapped = onOpen ? (
    <button
      type="button"
      className="h-bot-preview__button"
      aria-label={label}
      onClick={onOpen}
    >
      {body}
    </button>
  ) : (
    body
  );
  return (
    <div
      className={cx("h-bot-preview", className)}
      style={{
        maxWidth:
          state === "controlled"
            ? undefined
            : Math.min(MAX_WIDTH, MAX_HEIGHT * ratio),
      }}
    >
      {wrapped}
      {state === "frame" ? (
        <div
          className="h-bot-preview__caption"
          aria-hidden={onOpen ? true : undefined}
        >
          Hermes is in control
        </div>
      ) : null}
    </div>
  );
}
