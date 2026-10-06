import {
  AppShell,
  ShellNavigation,
  type ShellDestination,
} from "../AppShell/AppShell";
import type { ApprovalChoice } from "../ApprovalCard/ApprovalCard";
import { Button } from "../Button/Button";
import {
  ChatComposer,
  type ComposerAttachment,
  type QueuedPromptItem,
} from "../ChatComposer/ChatComposer";
import { ChatHeader } from "../ChatHeader/ChatHeader";
import { ChatThread, type ChatTurn } from "../ChatThread/ChatThread";
import { ModelPill } from "../ModelPill/ModelPill";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import {
  ThreadSidebar,
  type AccountAction,
  type ThreadAction,
  type ThreadItem,
} from "../ThreadSidebar/ThreadSidebar";
import {
  WelcomeView,
  type StarterPromptItem,
} from "../WelcomeView/WelcomeView";
import {
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./ChatScreen.css";

export interface ChatScreenProps {
  /**
   * `loaded` (default): the sidebar and the open chat. `loading`: the chats
   * are being fetched, a spinner fills the page. `failed`: "Could not load
   * your chats" with a Retry button. While loading or failed the app has no
   * sidebar yet; on a phone with more than one destination the app bar with
   * the menu button stays, so the drawer is still reachable.
   */
  state?: "loaded" | "loading" | "failed";
  /** The chats in the sidebar; see `ThreadSidebar`. On a Mac they sit in recency sections by `updatedAt`. */
  threads?: ThreadItem[];
  /** The open chat, whose title the header shows. None (or no turns) shows the welcome view. */
  selectedId?: string | null;
  /** The open chat's messages; empty shows the welcome view with `prompts`. */
  turns?: ChatTurn[];
  /** The welcome view's starter prompts; see `WelcomeView`. */
  prompts?: StarterPromptItem[];
  /** The signed-in user's name, for the welcome greeting. */
  greetingName?: string | null;
  /** The shell's destinations, Chat first; with only Chat the sidebar has no destination rows. */
  destinations?: ShellDestination[];
  /** The composer's text. */
  composerValue?: string;
  /** Files waiting in the composer. */
  attachments?: ComposerAttachment[];
  /** A reply is running: the send button becomes Stop. */
  replying?: boolean;
  /** Prompts queued behind the running reply. */
  queued?: QueuedPromptItem[];
  /** The model pill in the composer; null hides it (the server's model list failed). */
  model?: { model?: string; effort?: string } | null;
  /** Mac: the active profile, shown with the model under the toolbar title ("default · claude-opus-4"). */
  profile?: string;
  /** Mac: the window's size class for the toolbar; see `ChatHeader`'s `windowSize`. */
  windowSize?: "wide" | "medium" | "compact";
  /** Mac: a search is open with this query in the toolbar field. */
  searchQuery?: string;
  searchActive?: boolean;
  /** Account label in the sidebar footer. */
  account?: string;
  /** The server address at the top of the account menu. */
  serverUrl?: string;
  /** Mac: the day the sidebar's recency sections count back from (ISO date); see `ThreadSidebar`. */
  now?: string;
  /**
   * `desktop`: sidebar beside the chat (from 900px; 700px on a full-screen
   * iPad), the header above it. `phone`: the app bar with a menu button, the
   * sidebar in a drawer (`drawerOpen`).
   */
  layout?: "desktop" | "phone";
  /**
   * `apple` on `desktop` is a Mac window (unified 52px toolbar, the sidebar
   * as a source list under the traffic lights) unless `device="touch"`
   * (full-screen iPad); on `phone` it is the iPhone (44px navigation bar,
   * 44px rows, swipe actions). Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple` on `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
  /** Phone: show the drawer open over the chat. */
  drawerOpen?: boolean;
  /** Mac: draw the traffic lights, for previews of the whole window. */
  showTrafficLights?: boolean;
  /** Mac: start with the sidebar hidden. */
  sidebarCollapsed?: boolean;
  onSelectThread?: (id: string) => void;
  onNewThread?: () => void;
  onThreadAction?: (id: string, action: ThreadAction) => void;
  onAccountAction?: (action: AccountAction) => void;
  onSelectDestination?: (destination: ShellDestination) => void;
  onOpenMenu?: () => void;
  onCloseDrawer?: () => void;
  onShowConnection?: () => void;
  onPickPrompt?: (prompt: StarterPromptItem) => void;
  onComposerChange?: (value: string) => void;
  onSend?: (text: string) => void;
  onAttach?: () => void;
  onStop?: () => void;
  /** "Try again" under the latest reply. */
  onRetryReply?: () => void;
  onAnswerApproval?: (turn: number, choice: ApprovalChoice) => void;
  onAnswerClarify?: (turn: number, answers: Record<string, string[]>) => void;
  /** Retry after the chats failed to load (`state="failed"`). */
  onRetryLoad?: () => void;
}

/**
 * The whole chat screen as the app shows it: `AppShell` with a
 * `ThreadSidebar` (destinations from `ShellNavigation` on top), and on the
 * page a `ChatHeader`, the open chat as a `ChatThread` (or the `WelcomeView`
 * when no chat or an empty one is open) and the `ChatComposer` with a
 * `ModelPill`, in a centered column at most 680px wide. Use it as the
 * reference for any screen inside the chat, or as the starting frame of a
 * chat mock; give it a size (it fills its parent). The loading and failed
 * states replace the page as the app does, without the sidebar.
 */
export function ChatScreen({
  state = "loaded",
  threads = [],
  selectedId = null,
  turns = [],
  prompts,
  greetingName,
  destinations = ["chat", "kanban", "schedules"],
  composerValue,
  attachments,
  replying = false,
  queued,
  model = { model: "claude-opus-4" },
  profile,
  windowSize,
  searchQuery,
  searchActive,
  account,
  serverUrl,
  now,
  layout = "desktop",
  platform,
  device,
  drawerOpen = false,
  showTrafficLights = false,
  sidebarCollapsed = false,
  onSelectThread,
  onNewThread,
  onThreadAction,
  onAccountAction,
  onSelectDestination,
  onOpenMenu,
  onCloseDrawer,
  onShowConnection,
  onPickPrompt,
  onComposerChange,
  onSend,
  onAttach,
  onStop,
  onRetryReply,
  onAnswerApproval,
  onAnswerClarify,
  onRetryLoad,
}: ChatScreenProps) {
  const resolvedPlatform = usePlatform(platform);
  const phone = layout === "phone";

  if (state !== "loaded") {
    const body = (
      <div className="h-chat-screen__fill">
        {state === "loading" ? (
          <Spinner size={32} />
        ) : (
          <StateMessage
            title="Could not load your chats"
            action={<Button onClick={onRetryLoad}>Retry</Button>}
          />
        )}
      </div>
    );
    // A phone keeps the shell's menu, whose drawer is the plain shell
    // sidebar; a wide window shows the page alone until the chats arrive.
    if (phone && destinations.length > 1) {
      return (
        <AppShell
          layout="phone"
          platform={resolvedPlatform}
          destinations={destinations}
          current="chat"
          account={account}
          drawerOpen={drawerOpen}
          onSelect={onSelectDestination}
          onCloseDrawer={onCloseDrawer}
        >
          <ChatHeader layout="phone" remote={false} onOpenMenu={onOpenMenu} />
          {body}
        </AppShell>
      );
    }
    return (
      <PlatformScope platform={resolvedPlatform}>
        <div className="h-chat-screen">{body}</div>
      </PlatformScope>
    );
  }

  const selected = threads.find((t) => t.id === selectedId);
  const sidebar = (
    <ThreadSidebar
      threads={threads}
      selectedId={selectedId}
      now={now}
      layout={layout}
      account={account}
      serverUrl={serverUrl}
      navigation={
        destinations.length > 1 ? (
          <ShellNavigation
            destinations={destinations}
            current="chat"
            onSelect={onSelectDestination}
          />
        ) : undefined
      }
      onSelect={onSelectThread}
      onNewThread={onNewThread}
      onThreadAction={onThreadAction}
      onAccountAction={onAccountAction}
    />
  );
  return (
    <AppShell
      layout={layout}
      platform={resolvedPlatform}
      device={device}
      destinations={destinations}
      current="chat"
      sidebar={sidebar}
      drawerOpen={drawerOpen}
      showTrafficLights={showTrafficLights}
      sidebarCollapsed={sidebarCollapsed}
      onSelect={onSelectDestination}
      onCloseDrawer={onCloseDrawer}
    >
      <ChatHeader
        layout={layout}
        title={selected?.title}
        remote={selected?.remote !== false}
        pinned={selected?.pinned}
        onOpenMenu={onOpenMenu}
        onShowConnection={onShowConnection}
        onThreadAction={(action) =>
          selected && onThreadAction?.(selected.id, action)
        }
        subtitle={
          [profile, model?.model].filter(Boolean).join(" · ") || undefined
        }
        windowSize={windowSize}
        searchQuery={searchQuery}
        searchActive={searchActive}
        onNewChat={onNewThread}
        onCopyTranscript={
          selected
            ? () => onThreadAction?.(selected.id, "copy-transcript")
            : undefined
        }
      />
      {selected && turns.length ? (
        <ChatThread
          turns={turns}
          onRetry={onRetryReply}
          onAnswerApproval={onAnswerApproval}
          onAnswerClarify={onAnswerClarify}
        />
      ) : (
        <div className="h-chat-screen__fill">
          <WelcomeView
            greetingName={greetingName}
            prompts={prompts}
            onPick={onPickPrompt}
          />
        </div>
      )}
      <div className="h-chat-screen__composer">
        <ChatComposer
          value={composerValue}
          onChange={onComposerChange}
          onSend={onSend}
          onAttach={onAttach}
          attachments={attachments}
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
    </AppShell>
  );
}
