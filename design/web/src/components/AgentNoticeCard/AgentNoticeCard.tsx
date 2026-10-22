import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { NoticeDisclosure } from "./NoticeDisclosure";
import "./AgentNoticeCard.css";

/** How serious a notice is. `warn` and `error` draw the info icon in the error color, `success` in the primary color, anything else (`info`, or a level this app does not know) in muted gray. */
export type AgentNoticeLevel = "info" | "warn" | "error" | "success" | string;

export interface AgentNoticeCardProps {
  /** What Hermes reported, in one sentence ("Credits are running low. Review your account before continuing."). Cut to one line in the header, shown whole when the card is open. */
  text: string;
  /** Severity; defaults to `info`. */
  level?: AgentNoticeLevel;
  /** Start open, to preview the details. */
  defaultOpen?: boolean;
  /** Shows the close button in the header. The app passes it for every notice; the notice is removed from the panel when pressed. */
  onDismiss?: () => void;
  /** Called when the card is opened (not when it closes). */
  onDetails?: () => void;
}

/**
 * A notice the agent runtime raised outside the transcript, such as a credit
 * warning or a startup delay. It lives in the Activity panel's "This session"
 * list as a collapsed one-line tile: a leading info icon tinted by level, the
 * text cut to one line, a dismiss button and a chevron. Opening it shows the
 * whole text. Notices that expire disappear by themselves in the app.
 */
export function AgentNoticeCard({
  text,
  level = "info",
  defaultOpen = false,
  onDismiss,
  onDetails,
}: AgentNoticeCardProps) {
  const tone =
    level === "warn" || level === "error"
      ? "warn"
      : level === "success"
        ? "success"
        : "info";
  return (
    <NoticeDisclosure
      defaultOpen={defaultOpen}
      onToggle={(open) => {
        if (open) onDetails?.();
      }}
      title={
        <div className="h-agent-notice__row">
          <Icon
            name="info"
            apple="info_circle"
            size={18}
            className={`h-agent-notice__icon h-agent-notice__icon--${tone}`}
          />
          <span className="h-agent-notice__text h-notice-clamp1">{text}</span>
          {onDismiss ? (
            <IconButton
              icon="close"
              label="Dismiss notice"
              size={32}
              className="h-agent-notice__dismiss"
              onClick={(event) => {
                event.stopPropagation();
                onDismiss();
              }}
            />
          ) : null}
        </div>
      }
    >
      <div className="h-notice-text">{text}</div>
    </NoticeDisclosure>
  );
}
