import type { ReactNode } from "react";
import { IconButton } from "../IconButton/IconButton";
import { StateMessage } from "../StateMessage/StateMessage";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./ActivityPanel.css";

export interface ActivityPanelProps {
  /**
   * Live work of the session, listed under "Now": `SessionStatusCard`,
   * `ProcessOutputCard`, `MoaProgressCard`.
   */
  now?: ReactNode[];
  /** The agent's plan, listed under "Plan": a `TodoPlanCard` with `open`. */
  plan?: ReactNode;
  /**
   * Worth knowing, never urgent, listed under "This session":
   * `SessionUsageCard`, `SideResultCard`, `AgentNoticeCard`,
   * `SessionAcknowledgementCard`, a settled `BillingVerificationCard` or
   * `ConnectorOperationCard`.
   */
  session?: ReactNode[];
  /**
   * Adds the "Close activity" button to the title row; pass it for the
   * phone sheet, leave it out for the inspector (its toolbar toggle closes it).
   */
  onClose?: () => void;
  /**
   * `inspector` (default): fills the 380px inspector beside or over a wide
   * chat. `sheet`: the phone's detent sheet, with a grab handle on top.
   */
  frame?: "inspector" | "sheet";
  /** Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * The open chat's activity: Now (live work), Plan and This session
 * (reference), in that order, each under a small uppercase heading. A
 * section without content is left out; with none at all the panel says "No
 * activity for this chat". Shown as an inspector on wide layouts (see
 * `ChatScreen activityOpen`) and as a sheet on phones. The cards inside keep
 * their own look; the panel only orders and labels them.
 */
export function ActivityPanel({
  now = [],
  plan,
  session = [],
  onClose,
  frame = "inspector",
  platform,
}: ActivityPanelProps) {
  const resolved = usePlatform(platform);
  const empty = now.length === 0 && plan == null && session.length === 0;
  return (
    <PlatformScope platform={resolved}>
      <section
        className={cx("h-activity", `h-activity--${frame}`)}
        aria-label="Activity"
      >
        {frame === "sheet" ? (
          <div className="h-activity__handle" aria-hidden />
        ) : null}
        <div className="h-activity__head">
          <h2 className="h-activity__title">Activity</h2>
          {onClose ? (
            <IconButton icon="close" label="Close activity" onClick={onClose} />
          ) : null}
        </div>
        <div className="h-activity__body">
          {empty ? (
            <div className="h-activity__empty">
              <StateMessage
                icon="view_sidebar"
                title="No activity for this chat"
                detail="Plans, running work and session details show up here."
              />
            </div>
          ) : (
            <>
              {now.length > 0 ? (
                <ActivitySection title="Now">{now}</ActivitySection>
              ) : null}
              {plan != null ? (
                <ActivitySection title="Plan">{plan}</ActivitySection>
              ) : null}
              {session.length > 0 ? (
                <ActivitySection title="This session">
                  {session}
                </ActivitySection>
              ) : null}
            </>
          )}
        </div>
      </section>
    </PlatformScope>
  );
}

function ActivitySection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <div className="h-activity__section">
      <h3 className="h-activity__section-title">{title}</h3>
      {children}
    </div>
  );
}
