import { useState } from "react";
import type { ApprovalChoice } from "../ApprovalCard/ApprovalCard";
import { Button } from "../Button/Button";
import {
  ChatComposer,
  type ComposerAttachment,
  type QueuedPromptItem,
} from "../ChatComposer/ChatComposer";
import { ChatThread, type ChatTurn } from "../ChatThread/ChatThread";
import { MacToolbar, MacToolbarButton } from "../MacToolbar/MacToolbar";
import { Menu, MenuAnchor, type MenuItem } from "../Menu/Menu";
import { ModelPill } from "../ModelPill/ModelPill";
import { Spinner } from "../Spinner/Spinner";
import type { ThreadAction } from "../ThreadSidebar/ThreadSidebar";
import { PlatformScope, TRAFFIC_LIGHT_GAP } from "../../platform";
import "./ConversationWindowScreen.css";

/** The "…" menu's entries: a thread's Mac menu without Pin, which has its own button. */
type WindowAction = Extract<
  ThreadAction,
  "rename" | "copy-transcript" | "archive" | "delete"
>;

const menuItems: Array<MenuItem<WindowAction> | "divider"> = [
  { value: "rename", label: "Rename…" },
  { value: "copy-transcript", label: "Copy Transcript" },
  { value: "archive", label: "Archive" },
  "divider",
  { value: "delete", label: "Delete…", shortcut: "⌘⌫", destructive: true },
];

export interface ConversationWindowScreenProps {
  /**
   * `loaded` (default): the chat. `loading`: the chat is being fetched, an
   * activity indicator fills the window and only Show in Main Window works.
   * `failed`: "Could not open this chat" with a Close Window button.
   */
  state?: "loaded" | "loading" | "failed";
  /** The chat's title in the toolbar; while loading, the title the window was opened with. */
  title: string;
  /** The profile the window was opened from, shown with the model under the title: "work · hermes-4". */
  profile?: string;
  /** The chat is pinned: the toolbar's Pin button reads "Unpin", draws the filled pin and stays filled. */
  pinned?: boolean;
  /** The chat's messages, oldest first; see `ChatThread`. */
  turns?: ChatTurn[];
  /** The model pill in the composer and the model in the toolbar's subtitle; null hides both (the server's model list failed). */
  model?: { model?: string; effort?: string } | null;
  /** Show the toolbar's "…" menu open (Rename…, Copy Transcript, Archive, Delete… ⌘⌫), for previews. Clicking "…" toggles it. */
  menuOpen?: boolean;
  /** The composer's text, at first the draft carried over from the main window. */
  composerValue?: string;
  /** Files waiting in the composer, at first those carried over from the main window. */
  attachments?: ComposerAttachment[];
  /** A reply is running: the send button becomes Stop. */
  replying?: boolean;
  /** Prompts queued behind the running reply. */
  queued?: QueuedPromptItem[];
  /** Draw the traffic lights at the top left (default true), as the window has them. */
  showTrafficLights?: boolean;
  /** "Show in Main Window": the main window selects this chat and comes to the front. */
  onShowInMain?: () => void;
  /** Pin or Unpin (⇧⌘P). */
  onTogglePin?: () => void;
  /** Share: the system share picker under the button, with the transcript. */
  onShare?: () => void;
  /** An entry of the "…" menu. */
  onThreadAction?: (action: WindowAction) => void;
  /** "Close Window" after the chat failed to open. */
  onClose?: () => void;
  onComposerChange?: (value: string) => void;
  onSend?: (text: string) => void;
  onAttach?: () => void;
  /** An attachment chip's close button was pressed. */
  onRemoveAttachment?: (attachment: ComposerAttachment) => void;
  onStop?: () => void;
  /** "Try again" under the latest reply. */
  onRetryReply?: () => void;
  /** "Edit prompt" under the latest reply: the app drops that turn and puts its prompt back in the composer. */
  onEditPrompt?: () => void;
  onAnswerApproval?: (turn: number, choice: ApprovalChoice) => void;
  onAnswerClarify?: (turn: number, answers: Record<string, string[]>) => void;
}

/**
 * A conversation window (macOS only): one chat in a Mac window of its own,
 * opened from a chat's "Open in New Window ⌥⌘O", on the profile it was
 * opened from, with no sidebar. A 52px `MacToolbar` clears the traffic
 * lights and holds the chat's title over "profile · model", then Show in
 * Main Window, Pin (filled while pinned), Share and a "…" menu with Rename…,
 * Copy Transcript, Archive and Delete…; under it the chat's `ChatThread` and
 * the `ChatComposer` in the 680px column. Opening the main window's
 * selected chat moves it here (#444): the main window goes back to its
 * welcome view, and its composer's draft text and files start in this
 * window's composer (`composerValue`, `attachments`). There is no iOS or Material
 * version: other platforms open a chat in the main window only. Always draws
 * the Apple look; give it a size (it fills its parent).
 */
export function ConversationWindowScreen({
  state = "loaded",
  title,
  profile,
  pinned = false,
  turns = [],
  model = { model: "claude-opus-4" },
  menuOpen = false,
  composerValue,
  attachments,
  replying = false,
  queued,
  showTrafficLights = true,
  onShowInMain,
  onTogglePin,
  onShare,
  onThreadAction,
  onClose,
  onComposerChange,
  onSend,
  onAttach,
  onRemoveAttachment,
  onStop,
  onRetryReply,
  onEditPrompt,
  onAnswerApproval,
  onAnswerClarify,
}: ConversationWindowScreenProps) {
  const [open, setOpen] = useState(menuOpen);
  const loaded = state === "loaded";
  const subtitle =
    [profile, model?.model].filter(Boolean).join(" · ") || undefined;
  const actions = (
    <>
      <MacToolbarButton
        icon="view_sidebar"
        label="Show in Main Window"
        onClick={onShowInMain}
      />
      <MacToolbarButton
        icon="push_pin"
        apple={pinned ? "pin_fill" : "pin"}
        label={pinned ? "Unpin" : "Pin"}
        shortcut="⇧⌘P"
        selected={pinned}
        disabled={!loaded}
        onClick={onTogglePin}
      />
      <MacToolbarButton
        icon="ios_share"
        label="Share"
        disabled={!loaded}
        onClick={onShare}
      />
      <MenuAnchor>
        <MacToolbarButton
          icon="more_horiz"
          label="More"
          disabled={!loaded}
          onClick={() => setOpen((o) => !o)}
        />
        {open && loaded ? (
          <Menu
            align="end"
            device="mac"
            label="Chat actions"
            items={menuItems}
            onSelect={(item) => {
              setOpen(false);
              if (item.value) onThreadAction?.(item.value);
            }}
          />
        ) : null}
      </MenuAnchor>
    </>
  );
  return (
    <PlatformScope platform="apple">
      <div className="h-conversation-window">
        {showTrafficLights ? (
          <span
            className="h-conversation-window__traffic-lights h-traffic-lights"
            aria-hidden="true"
          >
            <span />
            <span />
            <span />
          </span>
        ) : null}
        <MacToolbar
          title={title}
          subtitle={subtitle}
          actions={actions}
          leadingInset={TRAFFIC_LIGHT_GAP + 8}
        />
        {state === "loading" ? (
          <div className="h-conversation-window__fill">
            <Spinner size={20} />
          </div>
        ) : state === "failed" ? (
          <div className="h-conversation-window__fill">
            <div className="h-conversation-window__failed">
              <span>Could not open this chat</span>
              <Button onClick={onClose}>Close Window</Button>
            </div>
          </div>
        ) : (
          <>
            <ChatThread
              turns={turns}
              onRetry={onRetryReply}
              onEdit={onEditPrompt}
              onAnswerApproval={onAnswerApproval}
              onAnswerClarify={onAnswerClarify}
            />
            <div className="h-conversation-window__composer">
              <ChatComposer
                value={composerValue}
                onChange={onComposerChange}
                onSend={onSend}
                onAttach={onAttach}
                attachments={attachments}
                onRemoveAttachment={onRemoveAttachment}
                replying={replying}
                onStop={onStop}
                queued={queued}
                modelPill={
                  model ? (
                    <ModelPill model={model.model} effort={model.effort} />
                  ) : undefined
                }
              />
            </div>
          </>
        )}
      </div>
    </PlatformScope>
  );
}
