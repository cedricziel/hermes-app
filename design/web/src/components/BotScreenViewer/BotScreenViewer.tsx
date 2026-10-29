import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { Spinner } from "../Spinner/Spinner";
import {
  cx,
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
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

/**
 * Who is driving. `watching`: the viewer only looks. `acquiring`: a take over
 * is on its way to the server. `in_control`: this device holds the control
 * lease. `releasing`: a hand back is on its way. `lost`: this device was in control and is no longer; the viewer says so
 * until it is dismissed.
 */
export type BotScreenViewerControl =
  "watching" | "acquiring" | "in_control" | "releasing" | "lost";

/** A full-screen page on a phone (shortest side under 600px), or an opaque layer over the whole window. */
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
  /**
   * Who is driving: `watching` (default), `acquiring` ("Taking over…"),
   * `in_control` (the subtitle says "You're in control" in amber, the stage
   * gets an amber frame and the header offers Hand Back), `releasing` (the
   * same, with the header saying "Handing back…" and no button) or `lost` (a
   * line under the header says who has the screen now, `lostText`, with
   * Dismiss, also while the picture is `blanked`). Only `live`,
   * `reconnecting` and, for `lost`, `blanked` show it.
   */
  control?: BotScreenViewerControl;
  /** `lost`: what the line says; "Hermes took control back." when the lease went back to Hermes. Default "Someone else took control.". */
  lostText?: string;
  /** `blanked`: the lease is held under a viewer id this app does not hold (another device, or this one before the app restarted), so the notice offers Hand back to Hermes (needs `onForceHandBack`). */
  canForce?: boolean;
  /** The profile's name, the header's title. */
  profile: string;
  /** `live` and `reconnecting`: the latest picture, an image URL or data URL. */
  pictureSrc?: string;
  /** Width over height of the screen; default 16 / 10. */
  aspectRatio?: number;
  /** `page` (default): the phone's full-screen page, a route with the platform's transition, Close at the leading edge, inside the safe area. `overlay`: the opaque layer over the whole window for a tablet or desktop; Escape (or Back) closes either; a dialog opened over it draws above it. */
  presentation?: BotScreenViewerPresentation;
  /** Close. */
  onClose?: () => void;
  /** Start Screen, in `off`; hidden without it. */
  onStart?: () => void;
  /** Try Again, in `unreachable` and `failed`; hidden without it. */
  onRetry?: () => void;
  /** Take over, in the header while a `live` picture is only watched (`watching` or `lost`); hidden without it. */
  onTakeOver?: () => void;
  /** Hand Back, in the header while `in_control`. */
  onHandBack?: () => void;
  /** Hand back to Hermes, in the `blanked` notice when `canForce`: it takes control from whoever holds it, so the app asks first. */
  onForceHandBack?: () => void;
  /** Dismiss, on the `lost` line. */
  onDismissLost?: () => void;
  /** Inherits the provider's platform. `apple` uses CupertinoIcons, a 44px bar on a page and a 52px one in an overlay; `material` a 56px bar. */
  platform?: Platform;
  /** Under `apple`: `mac` leaves room for the traffic lights, puts Close at the trailing edge and uses the 52px bar, as a page or as a layer. Left out, a layer is `mac` and a page is `touch` (iPhone and iPad). Ignored on `material`. */
  device?: AppleDevice;
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
 * The live view of the agent's own desktop (`BotScreenViewerView` in the app),
 * which the user can take over and hand back. Black in both themes like the
 * image viewer: a header that names the profile and who is in control
 * ("Hermes is in control" while the picture shows, "You're in control" after
 * Take over, "Someone else is in control" while it is blanked) with Take over
 * or Hand Back beside Close, and below it the picture, which the app lets be
 * pinched up to 4x, or the reason there is none. Fills its parent.
 */
export function BotScreenViewer({
  state,
  profile,
  pictureSrc,
  aspectRatio = 16 / 10,
  presentation = "page",
  control = "watching",
  lostText = "Someone else took control.",
  canForce = false,
  onClose,
  onStart,
  onRetry,
  onTakeOver,
  onHandBack,
  onForceHandBack,
  onDismissLost,
  platform,
  device,
}: BotScreenViewerProps) {
  const resolved = usePlatform(platform);
  const overlay = presentation === "overlay";
  const isLive = state === "live" || state === "reconnecting";
  const inControl =
    isLive && (control === "in_control" || control === "releasing");
  const subtitle = inControl
    ? "You're in control"
    : isLive
      ? "Hermes is in control"
      : state === "blanked"
        ? "Someone else is in control"
        : "Bot screen";
  const showsPicture =
    (state === "live" || state === "reconnecting") && pictureSrc;
  const picture = showsPicture ? (
    <div className="h-bot-viewer__picture">
      <img
        src={pictureSrc}
        alt="Hermes's screen"
        style={{ aspectRatio: String(aspectRatio) }}
      />
    </div>
  ) : null;
  const closeButton = (
    <IconButton icon="close" label="Close" onClick={onClose} />
  );
  const mac = resolved === "apple" && (device ? device === "mac" : overlay);
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
        : state === "blanked" && canForce && onForceHandBack
          ? { label: "Hand back to Hermes", run: onForceHandBack }
          : null;
  const headerAction = isLive && control === "releasing" ? (
    <Button variant="filled" compact disabled>
      Handing back…
    </Button>
  ) : inControl ? (
    <Button variant="filled" compact onClick={onHandBack}>
      Hand Back
    </Button>
  ) : state === "live" && control === "acquiring" ? (
    <Button variant="filled" compact disabled>
      Taking over…
    </Button>
  ) : state === "live" && onTakeOver ? (
    <Button variant="filled" compact onClick={onTakeOver}>
      Take over
    </Button>
  ) : null;
  return (
    <PlatformScope platform={resolved}>
      <div
        className={cx(
          "h-bot-viewer",
          resolved === "apple" && "h-bot-viewer--apple",
          mac && "h-bot-viewer--mac",
        )}
      >
        <header className="h-bot-viewer__bar">
          {mac ? <span className="h-bot-viewer__lights" /> : null}
          {!mac ? closeButton : null}
          <div className="h-bot-viewer__title" role="heading" aria-level={1}>
            <span>{profile}</span>
            <span
              className={cx(
                "h-bot-viewer__subtitle",
                inControl && "h-bot-viewer__subtitle--control",
              )}
            >
              {subtitle}
            </span>
          </div>
          {headerAction}
          {mac ? closeButton : null}
        </header>
        {(isLive || state === "blanked") && control === "lost" ? (
          <div className="h-bot-viewer__banner" role="status">
            <span>{lostText}</span>
            {onDismissLost ? (
              <IconButton
                icon="close"
                label="Dismiss"
                onClick={onDismissLost}
              />
            ) : null}
          </div>
        ) : null}
        <div className="h-bot-viewer__stage">
          {inControl ? <div className="h-bot-viewer__frame" /> : null}
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
