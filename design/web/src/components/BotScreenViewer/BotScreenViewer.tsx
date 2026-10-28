import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { Spinner } from "../Spinner/Spinner";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./BotScreenViewer.css";

/** What the viewer shows. */
export type BotScreenViewerState =
  | "connecting"
  | "live"
  | "reconnecting"
  | "blanked"
  | "off"
  | "not_allowed"
  | "unreachable"
  | "failed";

/** A full-screen page on a phone, or a layer over the whole window from 760px. */
export type BotScreenViewerPresentation = "page" | "overlay";

export interface BotScreenViewerProps {
  /**
   * `connecting`: asking for a ticket and opening the stream. `live`: the
   * picture arrives (`pictureSrc`). `reconnecting`: the stream dropped and is
   * being opened again; the last picture is dimmed under "Reconnecting…".
   * `blanked`: a person other than this device holds control, so there is no
   * picture. `off`: the screen is stopped, with Start Screen. `not_allowed`:
   * the server refused the connection (HTTP 403), no retry. `unreachable`:
   * five reconnect attempts failed, with Try Again. `failed`: a protocol
   * error or a ticket that kept being refused, with Try Again.
   */
  state: BotScreenViewerState;
  /** The profile's name, the header's title. */
  profile: string;
  /** `live` and `reconnecting`: the latest picture, an image URL or data URL. */
  pictureSrc?: string;
  /** Width over height of the screen; default 16 / 10. */
  aspectRatio?: number;
  /** `page` (default): the phone's full-screen page, Close at the leading edge, below the status bar. `overlay`: the layer over the whole window; on macOS it leaves room for the traffic lights and Close sits at the trailing edge; Esc closes it too. */
  presentation?: BotScreenViewerPresentation;
  /** Close. */
  onClose?: () => void;
  /** Start Screen, in `off`; hidden without it. */
  onStart?: () => void;
  /** Try Again, in `unreachable` and `failed`; hidden without it. */
  onRetry?: () => void;
  /** Inherits the provider's platform. `apple` uses CupertinoIcons, a 44px bar on a page and a 52px one in an overlay; `material` a 56px bar. */
  platform?: Platform;
}

const notices: Record<
  "blanked" | "off" | "not_allowed" | "unreachable" | "failed",
  { icon: string; title: string; text: string }
> = {
  blanked: {
    icon: "lock_outline",
    title: "Someone else is in control",
    text: "The picture returns when Hermes has control again.",
  },
  off: {
    icon: "desktop_windows_outlined",
    title: "The screen is off",
    text: "It starts by itself when Hermes needs it.",
  },
  not_allowed: {
    icon: "block",
    title: "Viewing isn't allowed from this app",
    text: "The server refused the connection to the screen.",
  },
  unreachable: {
    icon: "warning_amber_outlined",
    title: "Can't reach the screen",
    text: "Check the connection to the server.",
  },
  failed: {
    icon: "warning_amber_outlined",
    title: "The screen stopped sending",
    text: "The server ended the stream with an error.",
  },
};

/**
 * The live, watch-only view of the agent's own desktop (`BotScreenViewerView`
 * in the app). Black in both themes like the image viewer: a header that names
 * the profile and who is in control ("Hermes is in control" while the picture
 * shows, "Someone else is in control" while it is blanked), and below it the
 * picture, which the app lets be pinched up to 4x, or the reason there is
 * none. The viewer sends no input, so the picture has no hover or click
 * state. Fills its parent.
 */
export function BotScreenViewer({
  state,
  profile,
  pictureSrc,
  aspectRatio = 16 / 10,
  presentation = "page",
  onClose,
  onStart,
  onRetry,
  platform,
}: BotScreenViewerProps) {
  const resolved = usePlatform(platform);
  const overlay = presentation === "overlay";
  const control =
    state === "live" || state === "reconnecting"
      ? "Hermes is in control"
      : state === "blanked"
        ? "Someone else is in control"
        : "Bot screen";
  const showsPicture =
    (state === "live" || state === "reconnecting") && pictureSrc;
  const picture = showsPicture ? (
    <div
      className="h-bot-viewer__picture"
      style={{ aspectRatio: String(aspectRatio) }}
    >
      <img src={pictureSrc} alt="Hermes's screen" />
    </div>
  ) : null;
  const closeButton = (
    <IconButton
      icon="close"
      label="Close"
      onClick={onClose}
    />
  );
  const mac = resolved === "apple" && overlay;
  const notice =
    state === "blanked" ||
    state === "off" ||
    state === "not_allowed" ||
    state === "unreachable" ||
    state === "failed"
      ? notices[state]
      : null;
  const action =
    state === "off" && onStart
      ? { label: "Start Screen", run: onStart }
      : (state === "unreachable" || state === "failed") && onRetry
        ? { label: "Try Again", run: onRetry }
        : null;
  return (
    <PlatformScope platform={resolved}>
      <div
        className={cx(
          "h-bot-viewer",
          resolved === "apple" && "h-bot-viewer--apple",
          overlay && "h-bot-viewer--overlay",
        )}
      >
        <header className="h-bot-viewer__bar">
          {mac ? <span className="h-bot-viewer__lights" /> : null}
          {!mac ? closeButton : null}
          <div className="h-bot-viewer__title" role="heading" aria-level={1}>
            <span>{profile}</span>
            <span className="h-bot-viewer__subtitle">{control}</span>
          </div>
          {mac ? closeButton : null}
        </header>
        <div className="h-bot-viewer__stage">
          {state === "live" && picture ? picture : null}
          {state === "reconnecting" && picture ? (
            <>
              {picture}
              <div className="h-bot-viewer__dim" />
              <div className="h-bot-viewer__busy" role="status">
                <Spinner size={18} label="Reconnecting" />
                <span>Reconnecting…</span>
              </div>
            </>
          ) : null}
          {state === "connecting" ||
          ((state === "live" || state === "reconnecting") && !picture) ? (
            <div className="h-bot-viewer__busy" role="status">
              <Spinner size={18} label="Connecting" />
              <span>Connecting to the screen…</span>
            </div>
          ) : null}
          {notice ? (
            <div className="h-bot-viewer__notice" role="status">
              <Icon name={notice.icon} size={32} />
              <h2>{notice.title}</h2>
              <p>{notice.text}</p>
              {action ? (
                <Button variant="filled" onClick={action.run}>
                  {action.label}
                </Button>
              ) : null}
            </div>
          ) : null}
        </div>
      </div>
    </PlatformScope>
  );
}
