import { useState } from "react";
import { AlertDialog } from "../AlertDialog/AlertDialog";
import {
  ApprovalCard,
  type ApprovalChoice,
} from "../ApprovalCard/ApprovalCard";
import { Button } from "../Button/Button";
import { Card } from "../Card/Card";
import { groupInteractionLimitation } from "../CreateGroupDialog/CreateGroupDialog";
import { Icon } from "../Icon/Icon";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import { TextField } from "../TextField/TextField";
import { noop, ScreenCenter } from "../../screen";
import type { ScreenLayout } from "../../screenFrame";
import {
  useAppleDevice,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./BotGroupChatScreen.css";

/** One entry of a group room's transcript. */
export interface BotGroupEvent {
  id: string;
  /** Who wrote it: "You" or a member's name ("Research"). Its first letter is the avatar. */
  author: string;
  /** The message, for a user or member message. Leave out for an activity entry, which shows `activity` instead. */
  text?: string;
  /** An activity entry's label: "Started work", "Work completed", "Work failed — review details", "Group created". */
  activity?: string;
  /** The discussion thread it belongs to, shown at the card's trailing edge: "Topic 1". A message in a thread offers "Reply in thread". */
  thread?: string;
}

/** Something a member of the room waits for. */
export interface BotGroupPendingAction {
  id: string;
  /** The member's name; "Task needs attention" without one. */
  member?: string;
  /** `approval`: an approval card (Allow once, Deny). `retry`: a failed turn with "Review retry". `input`: a clarify, sudo or secret request the room cannot answer. */
  kind: "approval" | "retry" | "input";
  /** An approval's command: "rm -rf build/". */
  command?: string;
  /** What the approval is for, or why the turn needs a retry. */
  description?: string;
}

/** What the room asks before it acts, as the app's `GroupConfirmation`. */
export type BotGroupConfirmation = "disband" | "retryTask" | "retryMessage";

const confirmations: Record<
  BotGroupConfirmation,
  { title: (name: string) => string; detail: string; action: string }
> = {
  disband: {
    title: (name) => `Disband ${name}?`,
    detail:
      "This stops group work and removes the room from the roster. Membership cannot be changed.",
    action: "Disband group",
  },
  retryTask: {
    title: () => "Retry task?",
    detail:
      "The selected task is indeterminate or deferred. Review the room history before repeating its work.",
    action: "Retry task",
  },
  retryMessage: {
    title: () => "Retry message?",
    detail:
      "The app will check the durable log before retrying this exact message with its original identity.",
    action: "Retry message",
  },
};

export interface BotGroupChatScreenProps {
  /** The room's name: "Launch plan". */
  name: string;
  /** How many members it has; the subtitle reads "3 members". */
  memberCount: number;
  /** The transcript, oldest first. */
  events?: BotGroupEvent[];
  /** A member is working: the status card shows "Working", the limitation note and Stop. */
  working?: boolean;
  /** A member waits for an approval: "Waiting for approval" with a warning glyph, and Stop. */
  blocked?: boolean;
  /** What members wait for, as cards in the status card. While there are any, the limitation note is left out. */
  pendingActions?: BotGroupPendingAction[];
  /** The room's history could not be read: a notice with Retry over the transcript. */
  failure?: string;
  /** A send's receipt was lost: Send reads "Review message retry". */
  retrySend?: boolean;
  /** Why the room cannot run now (no ready driver), at the top of the status card; Send is disabled and approvals offer only Deny. */
  unavailableReason?: string;
  /** The composer's thread line: "New topic" or "Reply in Topic 1". */
  discussionLabel?: string;
  /** The message typed so far; Send is disabled while it is empty. */
  draft?: string;
  /** A send or Stop is in flight: Send reads "Sending…" and the buttons are disabled. */
  pending?: boolean;
  /** `loaded` (default); `loading` ("Loading room history" over the transcript); `disbanded` ("This room has been disbanded." alone). */
  state?: "loaded" | "loading" | "disbanded";
  /** Draw the "…" menu (Rename, Disband) open, for previews. */
  menuOpen?: boolean;
  /**
   * Draw a confirmation open, for previews: `disband` ("Disband Launch
   * plan?"), `retryTask` ("Retry task?", for the first `retry` action) or
   * `retryMessage` ("Retry message?"). Disband, Review retry and Review
   * message retry always ask first, in the app's Material alert on every
   * platform (Cancel, then the filled action); the callbacks run only on
   * confirm.
   */
  confirm?: BotGroupConfirmation;
  /** Back to Bots; the bar always draws it, as the room is pushed. */
  onBack?: () => void;
  onRename?: () => void;
  /** Disband was confirmed. */
  onDisband?: () => void;
  onStop?: () => void;
  onApprove?: (actionId: string, choice: ApprovalChoice) => void;
  /** A `retry` action's retry was confirmed. */
  onRetryAction?: (actionId: string) => void;
  onRetryLoad?: () => void;
  onReply?: (eventId: string) => void;
  onNewTopic?: () => void;
  onDraftChange?: (draft: string) => void;
  /** Send, or with `retrySend` the confirmed message retry. */
  onSend?: () => void;
  /** `phone` or `desktop`. Under `apple`, `desktop` draws the Mac window's 52px toolbar (back button, name over "3 members", "…"). */
  layout?: ScreenLayout;
  /**
   * The bar follows the platform, as the clean settings pages do: iOS
   * centred name over "3 members" with "‹ Bots"; Mac toolbar; Material
   * back arrow with the name at the start. The transcript and composer are
   * the app's own Material cards on every platform. Inherits the provider's
   * platform.
   */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

function EventCard({
  event,
  onReply,
}: {
  event: BotGroupEvent;
  onReply?: () => void;
}) {
  return (
    <Card className="h-group-chat__event">
      <div className="h-group-chat__event-head">
        <span className="h-group-chat__avatar" aria-hidden="true">
          {(Array.from(event.author)[0] ?? "?").toUpperCase()}
        </span>
        <span className="h-group-chat__author">{event.author}</span>
        {event.thread ? (
          <span className="h-group-chat__thread">{event.thread}</span>
        ) : null}
      </div>
      {event.text !== undefined ? (
        <>
          <p className="h-group-chat__text">{event.text}</p>
          {event.thread ? (
            <Button variant="text" icon="reply" compact onClick={onReply}>
              Reply in thread
            </Button>
          ) : null}
        </>
      ) : (
        <div className="h-group-chat__activity">
          <Icon name="expand_more" size={18} apple={false} />
          {event.activity}
        </div>
      )}
    </Card>
  );
}

/**
 * A hosted group room (`GroupChatScreen`), pushed from the Bots screen. Its
 * bar is the clean settings bar of the platform (`SettingsScaffold`): the
 * room's name over "3 members", back to Bots, and "…" with Rename and
 * Disband. Under it, in a centred column: a tinted status card (the
 * interactive-request limitation while members work, "Working" or
 * "Waiting for approval" and Stop), the transcript as bordered cards
 * (avatar initial, author, thread label, the text and "Reply in thread"),
 * and the composer pinned to the bottom: the thread line with "New topic",
 * "Message group" and a filled Send.
 */
export function BotGroupChatScreen({
  name,
  memberCount,
  events = [],
  pendingActions = [],
  failure,
  retrySend = false,
  working = false,
  blocked = false,
  unavailableReason,
  discussionLabel = "New topic",
  draft = "",
  pending = false,
  state = "loaded",
  menuOpen = false,
  confirm,
  onBack = noop,
  onRename,
  onDisband,
  onStop,
  onApprove,
  onRetryAction,
  onRetryLoad,
  onReply,
  onNewTopic,
  onDraftChange,
  onSend,
  layout = "phone",
  platform,
  device,
}: BotGroupChatScreenProps) {
  const appleDevice = useAppleDevice(layout, device);
  const actionable = !pending && state !== "disbanded";
  const running = working || blocked;
  const [asking, setAsking] = useState<{
    kind: BotGroupConfirmation;
    actionId?: string;
  } | null>(() =>
    confirm
      ? {
          kind: confirm,
          actionId: pendingActions.find((a) => a.kind === "retry")?.id,
        }
      : null,
  );
  const confirmation = asking ? confirmations[asking.kind] : undefined;
  const confirmed = () => {
    setAsking(null);
    if (!asking) return;
    if (asking.kind === "disband") onDisband?.();
    else if (asking.kind === "retryMessage") onSend?.();
    else if (asking.actionId !== undefined) onRetryAction?.(asking.actionId);
  };
  return (
    <SettingsScaffold
      title={name}
      subtitle={`${memberCount} members`}
      onBack={onBack}
      backLabel="Bots"
      actions={[
        {
          icon: "more_horiz",
          label: "Room actions",
          menu: [
            { label: "Rename", disabled: !actionable },
            { label: "Disband", disabled: !actionable },
          ],
          menuOpen,
          onSelect: (i) =>
            i === 0 ? onRename?.() : setAsking({ kind: "disband" }),
        },
      ]}
      platform={platform}
      device={appleDevice}
    >
      {state === "disbanded" ? (
        <ScreenCenter>
          <StateMessage title="This room has been disbanded." />
        </ScreenCenter>
      ) : (
        <div className="h-group-chat">
          <div className="h-group-chat__scroll">
            {state === "loading" ? (
              <div className="h-group-chat__loading">
                <Spinner size={16} />
                Loading room history
              </div>
            ) : null}
            {failure ? (
              <div className="h-group-chat__loading">
                <span>{failure}</span>
                <Button variant="text" compact onClick={onRetryLoad}>
                  Retry
                </Button>
              </div>
            ) : null}
            <div className="h-group-chat__status">
              {unavailableReason ? <p>{unavailableReason}</p> : null}
              {running && pendingActions.length === 0 ? (
                <p className="h-group-chat__note">
                  <Icon name="info" size={18} apple={false} />
                  <span>{groupInteractionLimitation}</span>
                </p>
              ) : null}
              <div className="h-group-chat__state">
                <Icon
                  name={
                    blocked ? "warning" : working ? "autorenew" : "check_circle"
                  }
                  size={18}
                  apple={false}
                />
                <span>
                  {blocked
                    ? "Waiting for approval"
                    : working
                      ? "Working"
                      : "Idle"}
                </span>
                {running ? (
                  <Button
                    variant="outlined"
                    compact
                    disabled={pending}
                    onClick={onStop}
                  >
                    Stop
                  </Button>
                ) : null}
              </div>
              {pendingActions.map((action) => (
                <Card
                  key={action.id}
                  padding={12}
                  className="h-group-chat__action"
                >
                  <div>{action.member ?? "Task needs attention"}</div>
                  {action.kind === "approval" ? (
                    <ApprovalCard
                      command={action.command}
                      description={
                        action.description ??
                        "This member is waiting for your approval."
                      }
                      choices={unavailableReason ? ["deny"] : ["once", "deny"]}
                      disabled={pending}
                      onAnswer={(choice) => onApprove?.(action.id, choice)}
                    />
                  ) : (
                    <div>{action.description ?? `Pending ${action.kind}`}</div>
                  )}
                  {action.kind === "input" ? (
                    <div className="h-muted">
                      This input cannot be answered in the hosted room. Stop the
                      task if it stalls.
                    </div>
                  ) : null}
                  {action.kind === "retry" ? (
                    <Button
                      variant="text"
                      compact
                      disabled={pending || !!unavailableReason}
                      onClick={() =>
                        setAsking({ kind: "retryTask", actionId: action.id })
                      }
                    >
                      Review retry
                    </Button>
                  ) : null}
                </Card>
              ))}
            </div>
            {events.map((event) => (
              <EventCard
                key={event.id}
                event={event}
                onReply={() => onReply?.(event.id)}
              />
            ))}
          </div>
          <div className="h-group-chat__composer">
            <div className="h-group-chat__topic">
              <Icon name="forum" size={18} apple={false} />
              <span className="h-group-chat__topic-label">
                {discussionLabel}
              </span>
              <Button
                variant="text"
                compact
                disabled={pending}
                onClick={onNewTopic}
              >
                New topic
              </Button>
            </div>
            <TextField
              placeholder="Message group"
              aria-label="Message group"
              value={draft}
              onChange={(e) => onDraftChange?.(e.target.value)}
            />
            <div className="h-group-chat__send">
              <Button
                icon="arrow_upward"
                disabled={!!unavailableReason || pending || draft.trim() === ""}
                onClick={() =>
                  retrySend ? setAsking({ kind: "retryMessage" }) : onSend?.()
                }
              >
                {pending
                  ? "Sending…"
                  : retrySend
                    ? "Review message retry"
                    : "Send"}
              </Button>
            </div>
          </div>
        </div>
      )}
      {confirmation ? (
        <AlertDialog
          platform="material"
          title={confirmation.title(name)}
          message={confirmation.detail}
          actions={[
            { label: "Cancel", onClick: () => setAsking(null) },
            {
              label: confirmation.action,
              isDefault: true,
              onClick: confirmed,
            },
          ]}
          onDismiss={() => setAsking(null)}
        />
      ) : null}
    </SettingsScaffold>
  );
}
