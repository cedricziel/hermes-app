import { Icon } from "../Icon/Icon";
import "./UserMessage.css";

export interface MessageAttachment {
  /** File name, e.g. `quarterly-report-final-v3.pdf`. Cut with an ellipsis when long. */
  name: string;
  /** `image` shows a thumbnail when `src` is given; `file` (default) a card with an icon, the name and the size. */
  kind?: "image" | "file";
  /** Image URL (or data URI) for an image thumbnail. Without it an image shows as a file card. */
  src?: string;
  /** Size under the name, already formatted: `2.3 MB`, `14 KB`, `1 B`. */
  size?: string;
  /** Replaces the size with a status line, e.g. `Downloading…` or `This file is no longer available.` */
  notice?: string;
  /** Draws `notice` in the error color. */
  noticeIsError?: boolean;
}

export interface UserMessageProps {
  /** What the user wrote. Leave out for a turn that only sent attachments. */
  text?: string;
  /** Files sent with the turn, stacked right-aligned above the text, 8px apart. */
  attachments?: MessageAttachment[];
}

/**
 * The user's turn in a chat: a right-aligned bubble in the high surface color
 * with a 14px radius, with any attached images (240px thumbnails) and files
 * (cards with name and size) stacked above it.
 */
export function UserMessage({ text, attachments = [] }: UserMessageProps) {
  return (
    <div className="h-user-message">
      {attachments.map((file, i) => (
        <AttachmentView key={`${file.name}-${i}`} attachment={file} />
      ))}
      {text ? <div className="h-user-message__bubble">{text}</div> : null}
    </div>
  );
}

function AttachmentView({ attachment }: { attachment: MessageAttachment }) {
  if (attachment.kind === "image" && attachment.src) {
    return (
      <img
        className="h-user-message__thumbnail"
        src={attachment.src}
        alt={attachment.name}
      />
    );
  }
  const subtitle = attachment.notice ?? attachment.size;
  return (
    <div className="h-user-message__file">
      <Icon
        name={attachment.kind === "image" ? "image" : "draft"}
        size={20}
        className="h-user-message__file-icon"
      />
      <div className="h-user-message__file-text">
        <div className="h-user-message__file-name">{attachment.name}</div>
        {subtitle ? (
          <div
            className={[
              "h-user-message__file-meta",
              attachment.notice && attachment.noticeIsError
                ? "h-user-message__file-meta--error"
                : null,
            ]
              .filter(Boolean)
              .join(" ")}
          >
            {subtitle}
          </div>
        ) : null}
      </div>
    </div>
  );
}
