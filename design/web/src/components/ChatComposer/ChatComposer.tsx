import { useState, type KeyboardEvent, type ReactNode } from "react";
import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import "./ChatComposer.css";

export interface ComposerAttachment {
  /** File name shown on the chip, e.g. `quarterly-report-final-v3.pdf`. */
  name: string;
  /** Draws the chip with an image icon instead of a file icon. */
  image?: boolean;
  /** Voice attachments use the microphone glyph. */
  audio?: boolean;
}

export interface QueuedPromptItem {
  /** The queued text. Empty for a prompt that only carries files; the chip then lists their names. */
  text: string;
  /** Names of files queued with the prompt; with text, shown as a paperclip and a count. */
  files?: string[];
  /** A restored entry whose earlier send may already have reached Hermes: the queue shows "Submission outcome unknown" and offers no "Send now" while it is first. */
  uncertain?: boolean;
  /** The entry is being sent right now, so its remove button is disabled. */
  submitting?: boolean;
}

export interface ChatComposerProps {
  /** Preview of native hold-to-record state. Capture is owned by Flutter. */
  voiceRecording?: {
    phase: "preparing" | "recording" | "attaching";
    elapsedSeconds?: number;
  };
  onCancelVoiceRecording?: () => void;
  onFinishVoiceRecording?: () => void;
  /** Text in the field. Controlled when given together with `onChange`; otherwise the initial text. */
  value?: string;
  /** Called with the field's text as the user types. */
  onChange?: (value: string) => void;
  /** Called with the trimmed text when the user presses send or Enter (Shift+Enter breaks the line). */
  onSend?: (text: string) => void;
  /** Shows the muted `+` attach button and is called by it. */
  onAttach?: () => void;
  /** Files picked for the next message, shown as removable chips above the card. They make the send button active on their own. */
  attachments?: ComposerAttachment[];
  /** Called with the attachment whose chip's close button was pressed. */
  onRemoveAttachment?: (attachment: ComposerAttachment) => void;
  /** A reply is in flight: shows Stop beside the field and the hint becomes "Queue a message…". */
  replying?: boolean;
  /** Called by the Stop button. */
  onStop?: () => void;
  /** Stop was pressed and is being processed: the Stop button is disabled. */
  stopping?: boolean;
  /** Prompts waiting for the reply to end, collapsed inside the card. */
  queued?: QueuedPromptItem[];
  /** The queue is paused after a stopped or failed reply: the header reads "Queue paused" with a "Send now" button. */
  queuePaused?: boolean;
  /** Called by "Send now" on a paused queue. */
  onSendQueued?: () => void;
  /** Called with the index of the queued prompt whose close button was pressed. */
  onRemoveQueued?: (index: number) => void;
  /** The queue was restored from storage (after a restart): the header reads "Recovered queue. Review before sending." and the button "Send next", one explicit send per entry. */
  queueReviewRequired?: boolean;
  /** Entries are being saved to the durable queue: the header reads "Queueing…" and the remove buttons are disabled. */
  queueBusy?: boolean;
  /** The recovered queue's original conversation can't be reached: "Original conversation unavailable." shows and "Send next" is hidden. Defaults to `true`. */
  queueAvailable?: boolean;
  /** App Lock is on: the queue shows only "Unlock to review queued prompts." and no prompt text. */
  queueLocked?: boolean;
  /** A storage problem to tell the user about under the queue header, e.g. "Protected storage is unavailable. Your draft was kept." While it shows, the queue offers no "Send now" / "Send next". */
  queueError?: string;
  /** Called by "Inspect conversation", shown under an uncertain entry. */
  onInspectQueue?: () => void;
  /** Slot left of the send button for the model pill, normally `<ModelPill model="claude-opus-4" effort="Medium" />`. */
  modelPill?: ReactNode;
  /** Overrides the hint text ("Message Hermes…", or "Queue a message…" while replying). */
  placeholder?: string;
  /** Teammate or slash-command results, normally a ChatSuggestions panel. */
  suggestions?: ReactNode;
}

/**
 * The chat composer at the bottom of a conversation: a rounded card with the
 * text field on top and attach (+), the model pill and the round send arrow
 * below it. Stop sits beside the field; the queue expands inside the card.
 * Attachment chips sit above it.
 */
export function ChatComposer({
  value,
  onChange,
  onSend,
  onAttach,
  attachments = [],
  onRemoveAttachment,
  replying = false,
  onStop,
  stopping = false,
  queued = [],
  queuePaused = false,
  onSendQueued,
  onRemoveQueued,
  queueReviewRequired = false,
  queueBusy = false,
  queueAvailable = true,
  queueLocked = false,
  queueError,
  onInspectQueue,
  modelPill,
  placeholder,
  suggestions,
  voiceRecording,
  onCancelVoiceRecording,
  onFinishVoiceRecording,
}: ChatComposerProps) {
  const [local, setLocal] = useState(value ?? "");
  const text = value !== undefined && onChange ? value : local;
  const canSend =
    !voiceRecording && (text.trim() !== "" || attachments.length > 0);
  const seconds = Math.max(0, Math.floor(voiceRecording?.elapsedSeconds ?? 0));
  const recordingLabel =
    voiceRecording?.phase === "preparing"
      ? "Preparing microphone…"
      : voiceRecording?.phase === "attaching"
        ? "Attaching recording…"
        : `Release to attach · ${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
  const anyUncertain = queued.some((prompt) => prompt.uncertain);
  const canSendQueued =
    (queuePaused || queueReviewRequired) &&
    queueAvailable &&
    !queueBusy &&
    !queueError &&
    !queued[0]?.uncertain;
  // As the app's QueuedPrompts: a queue that needs the user opens itself and
  // says so in its one-line summary.
  const queueAttention =
    queuePaused ||
    queueReviewRequired ||
    !queueAvailable ||
    !!queueError ||
    anyUncertain;

  const update = (next: string) => {
    setLocal(next);
    onChange?.(next);
  };
  const send = () => {
    if (canSend) onSend?.(text.trim());
  };
  const onKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      send();
    }
  };

  return (
    <div className="h-chat-composer">
      {suggestions}
      {attachments.length > 0 ? (
        <div className="h-chat-composer__attachments">
          {attachments.map((file, i) => (
            <Chip
              key={`${file.name}-${i}`}
              icon={file.image ? "image" : file.audio ? "mic" : "draft"}
              label={file.name}
              onRemove={() => onRemoveAttachment?.(file)}
            />
          ))}
        </div>
      ) : null}
      <div className="h-chat-composer__card">
        {queueLocked && queued.length > 0 ? (
          <div className="h-chat-composer__queue h-chat-composer__queue--locked">
            Unlock to review queued prompts.
          </div>
        ) : queued.length > 0 || queueBusy || queueReviewRequired ? (
          <details
            className="h-chat-composer__queue"
            open={queueAttention || undefined}
          >
            <summary>
              <span>
                {queueBusy
                  ? "Queueing…"
                  : queueReviewRequired
                    ? "Review queued messages"
                    : canSendQueued
                      ? `Queue paused · ${queued.length}`
                      : queueAttention
                        ? "Queue needs attention"
                        : `${queued.length} queued · ${queued[0].text || queued[0].files?.join(", ") || "Attachments"}`}
              </span>
              <Icon name="expand_more" size={18} />
            </summary>
            <div className="h-chat-composer__queue-details">
              <div className="h-chat-composer__bar h-chat-composer__bar--queue">
                <span className="h-chat-composer__bar-text">
                  {queueBusy
                    ? "Saving queued messages…"
                    : queueReviewRequired
                      ? "Recovered queue. Review before sending."
                      : canSendQueued
                        ? "Queue paused"
                        : "Queued, sent when Hermes is done"}
                </span>
                {canSendQueued ? (
                  <Button variant="text" icon="send" onClick={onSendQueued}>
                    {queueReviewRequired ? "Send next" : "Send now"}
                  </Button>
                ) : null}
              </div>
              {!queueAvailable ? (
                <div className="h-chat-composer__queue-note">
                  Original conversation unavailable.
                </div>
              ) : null}
              {queueError ? (
                <div className="h-chat-composer__queue-note">{queueError}</div>
              ) : null}
              {anyUncertain ? (
                <div className="h-chat-composer__queue-note">
                  <div>Submission outcome unknown</div>
                  <div>
                    An earlier attempt may already have reached Hermes. To send
                    it again, enter a new prompt.
                  </div>
                  {onInspectQueue ? (
                    <div className="h-chat-composer__inspect">
                      <Button variant="text" onClick={onInspectQueue}>
                        Inspect conversation
                      </Button>
                    </div>
                  ) : null}
                </div>
              ) : null}
              {queued.map((prompt, i) => {
                const files = prompt.files ?? [];
                return (
                  <div className="h-chat-composer__queued" key={i}>
                    <Icon
                      name="schedule"
                      size={16}
                      className="h-chat-composer__muted"
                    />
                    <span className="h-chat-composer__queued-text">
                      {prompt.text || files.join(", ")}
                    </span>
                    {prompt.text && files.length > 0 ? (
                      <span className="h-chat-composer__queued-files">
                        <Icon name="attach_file" size={16} />
                        {files.length}
                      </span>
                    ) : null}
                    <IconButton
                      icon="close"
                      label="Remove from queue"
                      size={32}
                      disabled={queueBusy || prompt.submitting}
                      onClick={() => onRemoveQueued?.(i)}
                    />
                  </div>
                );
              })}
            </div>
          </details>
        ) : null}

        <div className="h-chat-composer__field-row">
          <textarea
            className="h-chat-composer__field"
            rows={1}
            readOnly={!!voiceRecording}
            value={text}
            placeholder={
              placeholder ?? (replying ? "Queue a message…" : "Message Hermes…")
            }
            onChange={(event) => update(event.target.value)}
            onKeyDown={onKeyDown}
          />
          {replying && onStop ? (
            <IconButton
              icon="stop_circle"
              label="Stop response"
              disabled={stopping}
              onClick={onStop}
            />
          ) : null}
        </div>
        <div className="h-chat-composer__row">
          {voiceRecording ? (
            <IconButton
              icon="close"
              label="Cancel voice message"
              tone="muted"
              onClick={onCancelVoiceRecording}
            />
          ) : onAttach ? (
            <IconButton
              icon="add"
              label="Add attachment"
              tone="muted"
              onClick={onAttach}
            />
          ) : null}
          <div
            className={`h-chat-composer__pill${voiceRecording ? " h-chat-composer__recording" : ""}${voiceRecording?.phase === "recording" ? " h-chat-composer__recording--active" : ""}`}
          >
            {voiceRecording ? recordingLabel : modelPill}
          </div>
          <IconButton
            icon={voiceRecording ? "mic" : "arrow_upward"}
            label={voiceRecording ? "Attach voice message" : "Send"}
            variant="filled"
            disabled={
              voiceRecording ? voiceRecording.phase === "attaching" : !canSend
            }
            onClick={voiceRecording ? onFinishVoiceRecording : send}
          />
        </div>
      </div>
    </div>
  );
}
