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
}

export interface QueuedPromptItem {
  /** The queued text. Empty for a prompt that only carries files; the chip then lists their names. */
  text: string;
  /** Names of files queued with the prompt; with text, shown as a paperclip and a count. */
  files?: string[];
}

export interface ChatComposerProps {
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
  /** A reply is in flight: shows the "Hermes is replying… Stop" bar above the card and the hint becomes "Queue a message…". */
  replying?: boolean;
  /** Called by the Stop button. */
  onStop?: () => void;
  /** Stop was pressed and is being processed: the Stop button is disabled. */
  stopping?: boolean;
  /** Prompts waiting for the current reply to end, listed above the card. */
  queued?: QueuedPromptItem[];
  /** The queue is paused after a stopped or failed reply: the header reads "Queue paused" with a "Send now" button. */
  queuePaused?: boolean;
  /** Called by "Send now" on a paused queue. */
  onSendQueued?: () => void;
  /** Called with the index of the queued prompt whose close button was pressed. */
  onRemoveQueued?: (index: number) => void;
  /** Slot left of the send button for the model pill, normally `<ModelPill model="claude-opus-4" effort="Medium" />`. */
  modelPill?: ReactNode;
  /** Overrides the hint text ("Message Hermes…", or "Queue a message…" while replying). */
  placeholder?: string;
}

/**
 * The chat composer at the bottom of a conversation: a rounded card with the
 * text field on top and attach (+), the model pill and the round send arrow
 * below it. Above the card it lists the stop bar while Hermes replies, the
 * queued prompts and the attachment chips.
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
  modelPill,
  placeholder,
}: ChatComposerProps) {
  const [local, setLocal] = useState(value ?? "");
  const text = value !== undefined && onChange ? value : local;
  const canSend = text.trim() !== "" || attachments.length > 0;

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
      {replying ? (
        <div className="h-chat-composer__bar">
          <span className="h-chat-composer__bar-text">Hermes is replying…</span>
          <Button
            variant="text"
            icon="stop_circle"
            disabled={stopping}
            onClick={onStop}
          >
            Stop
          </Button>
        </div>
      ) : null}
      {queued.length > 0 ? (
        <div className="h-chat-composer__queue">
          <div className="h-chat-composer__bar h-chat-composer__bar--queue">
            <span className="h-chat-composer__bar-text">
              {queuePaused
                ? "Queue paused"
                : "Queued, sent when Hermes is done"}
            </span>
            {queuePaused ? (
              <Button variant="text" icon="send" onClick={onSendQueued}>
                Send now
              </Button>
            ) : null}
          </div>
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
                  onClick={() => onRemoveQueued?.(i)}
                />
              </div>
            );
          })}
        </div>
      ) : null}
      {attachments.length > 0 ? (
        <div className="h-chat-composer__attachments">
          {attachments.map((file, i) => (
            <Chip
              key={`${file.name}-${i}`}
              icon={file.image ? "image" : "draft"}
              label={file.name}
              onRemove={() => onRemoveAttachment?.(file)}
            />
          ))}
        </div>
      ) : null}
      <div className="h-chat-composer__card">
        <textarea
          className="h-chat-composer__field"
          rows={1}
          value={text}
          placeholder={
            placeholder ?? (replying ? "Queue a message…" : "Message Hermes…")
          }
          onChange={(event) => update(event.target.value)}
          onKeyDown={onKeyDown}
        />
        <div className="h-chat-composer__row">
          {onAttach ? (
            <IconButton
              icon="add"
              label="Add attachment"
              tone="muted"
              onClick={onAttach}
            />
          ) : null}
          <div className="h-chat-composer__pill">{modelPill}</div>
          <IconButton
            icon="arrow_upward"
            label="Send"
            variant="filled"
            disabled={!canSend}
            onClick={send}
          />
        </div>
      </div>
    </div>
  );
}
