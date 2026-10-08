import {
  ApprovalCard,
  type ApprovalCardProps,
  type ApprovalChoice,
} from "../ApprovalCard/ApprovalCard";
import { AssistantMessage } from "../AssistantMessage/AssistantMessage";
import { ClarifyCard, type ClarifyCardProps } from "../ClarifyCard/ClarifyCard";
import { ReasoningBlock } from "../ReasoningBlock/ReasoningBlock";
import { ThinkingIndicator } from "../ThinkingIndicator/ThinkingIndicator";
import type { ToolCallItem } from "../ToolCallCard/ToolCallCard";
import { ToolCallGroup } from "../ToolCallGroup/ToolCallGroup";
import {
  UserMessage,
  type MessageAttachment,
} from "../UserMessage/UserMessage";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "./ChatThread.css";

/** What the user sent: a right-aligned bubble with its attachments above it. */
export interface UserTurn {
  role: "user";
  text?: string;
  attachments?: MessageAttachment[];
}

/**
 * One reply of Hermes, drawn top to bottom in the order the app shows its
 * parts: the reasoning, text written before the tools ran (`prose`), the run
 * of tool calls, a standalone approval or clarify request, the final `text`
 * with its actions, and the thinking indicator while nothing has arrived.
 */
export interface AssistantTurn {
  role: "assistant";
  /** The model's reasoning, folded under "Thought for …" (see `ReasoningBlock`). */
  reasoning?: string;
  /** The reasoning is still streaming: the block reads "Thinking…". */
  reasoningActive?: boolean;
  /** Text Hermes wrote before its tool calls, kept where it was written. */
  prose?: string;
  /** The run of tool calls, folded into one `ToolCallGroup`. A call's own `approval` is drawn inside its card. */
  toolCalls?: ToolCallItem[];
  /** Folds the tool calls open initially. */
  toolCallsOpen?: boolean;
  /** An approval Hermes asks for outside a tool call. */
  approval?: Omit<ApprovalCardProps, "onAnswer">;
  /** A question Hermes asks (see `ClarifyCard`). */
  clarify?: Omit<ClarifyCardProps, "onAnswer">;
  /** The reply's text (Markdown, see `AssistantMessage`). */
  text?: string;
  /** Text is still arriving: no actions under it yet. */
  streaming?: boolean;
  /** The user stopped the reply: "Stopped" in the actions. */
  stopped?: boolean;
  /** The reply failed: a red note under what arrived. */
  error?: string;
  /** What Hermes' background review saved after this reply (see `AssistantMessage` `reviewNotes`). */
  reviewNotes?: string[];
  /** Nothing has arrived for a while: the thinking indicator, with seconds elapsed and what Hermes is doing. */
  thinking?: { elapsedSeconds: number; activity?: string };
}

/** One entry of a chat: what the user sent or Hermes' reply. */
export type ChatTurn = UserTurn | AssistantTurn;

export interface ChatThreadProps {
  /** The chat's turns, oldest first. */
  turns: ChatTurn[];
  /** "Try again" under the latest finished reply (the app offers it on that one only). */
  onRetry?: () => void;
  /** "Edit prompt" under the latest finished reply, next to "Try again": the app drops that turn and puts its prompt back in the composer. */
  onEdit?: () => void;
  /** An approval was answered; `turn` is its index in `turns`. */
  onAnswerApproval?: (turn: number, choice: ApprovalChoice) => void;
  /** A clarify request was answered; `turn` is its index in `turns`. */
  onAnswerClarify?: (turn: number, answers: Record<string, string[]>) => void;
  /** `apple`: 44px message actions and the iOS type ramp's message size. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * The scrolling messages of an open chat, without header or composer: a
 * column at most 680px wide, centered, with 20px gutters, 20px between turns
 * and 8px between the parts of one reply, as the app's chat list. It fills
 * its parent and scrolls; `ChatScreen` puts it between `ChatHeader` and
 * `ChatComposer`. Build each turn from plain data (`ChatTurn`); for a part
 * the turn model lacks, compose `UserMessage`, `AssistantMessage` and the
 * agent activity cards yourself.
 */
export function ChatThread({
  turns,
  onRetry,
  onEdit,
  onAnswerApproval,
  onAnswerClarify,
  platform,
}: ChatThreadProps) {
  const resolvedPlatform = usePlatform(platform);
  let latest = -1;
  turns.forEach((t, i) => {
    if (t.role === "assistant" && t.text && !t.streaming) latest = i;
  });
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div className="h-chat-thread">
        <div className="h-chat-thread__column">
          {turns.map((turn, i) => (
            <div key={i} className="h-chat-thread__turn">
              {turn.role === "user" ? (
                <UserMessage text={turn.text} attachments={turn.attachments} />
              ) : (
                <AssistantTurnParts
                  turn={turn}
                  onRetry={i === latest ? onRetry : undefined}
                  onEdit={i === latest ? onEdit : undefined}
                  onAnswerApproval={(choice) => onAnswerApproval?.(i, choice)}
                  onAnswerClarify={(answers) => onAnswerClarify?.(i, answers)}
                />
              )}
            </div>
          ))}
        </div>
      </div>
    </PlatformScope>
  );
}

function AssistantTurnParts({
  turn,
  onRetry,
  onEdit,
  onAnswerApproval,
  onAnswerClarify,
}: {
  turn: AssistantTurn;
  onRetry?: () => void;
  onEdit?: () => void;
  onAnswerApproval: (choice: ApprovalChoice) => void;
  onAnswerClarify: (answers: Record<string, string[]>) => void;
}) {
  return (
    <>
      {turn.reasoning ? (
        <ReasoningBlock text={turn.reasoning} active={turn.reasoningActive} />
      ) : null}
      {turn.prose ? (
        <AssistantMessage text={turn.prose} showCopy={false} />
      ) : null}
      {turn.toolCalls?.length ? (
        <ToolCallGroup
          calls={turn.toolCalls}
          defaultOpen={turn.toolCallsOpen}
        />
      ) : null}
      {turn.approval ? (
        <ApprovalCard {...turn.approval} onAnswer={onAnswerApproval} />
      ) : null}
      {turn.clarify ? (
        <ClarifyCard {...turn.clarify} onAnswer={onAnswerClarify} />
      ) : null}
      {turn.text || turn.error || turn.stopped ? (
        <AssistantMessage
          text={turn.text}
          streaming={turn.streaming}
          stopped={turn.stopped}
          error={turn.error}
          onRetry={onRetry}
          onEdit={onEdit}
          reviewNotes={turn.reviewNotes}
        />
      ) : null}
      {turn.thinking ? <ThinkingIndicator {...turn.thinking} /> : null}
    </>
  );
}
