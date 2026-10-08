import type { ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./AssistantMessage.css";

export interface AssistantMessageProps {
  /**
   * The reply as Markdown. Supported: paragraphs, `#`–`###` headings, `-`/`*`
   * and `1.` lists, fenced code blocks (with a language label and a copy
   * button), `**bold**`, `*italic*`, `` `inline code` ``, `[links](url)` and
   * bare `https://` URLs. Ignored when `children` is given.
   */
  text?: string;
  /** Custom content instead of `text`, for anything the built-in Markdown renderer cannot express. */
  children?: ReactNode;
  /** Why the reply failed, shown in the error color with an `error` icon under whatever text it kept. */
  error?: string;
  /** The reply is still streaming: the action row is hidden. */
  streaming?: boolean;
  /** The user stopped the reply: the action row starts with "Stopped". */
  stopped?: boolean;
  /** Show the copy action. Defaults to true when there is text; false for a failed reply that kept none. */
  showCopy?: boolean;
  /** The copy action shows a check, as it does for two seconds after copying. */
  copied?: boolean;
  /** Called by the copy action. */
  onCopy?: () => void;
  /** Shows the "Try again" action (only on the latest reply) and is called by it. */
  onRetry?: () => void;
  /** Shows the "Edit prompt" action after "Try again" (only on the latest reply): the app drops that turn and puts its prompt back in the composer. */
  onEdit?: () => void;
  /**
   * What Hermes' background review saved after reading this reply, one entry
   * per change ("Memory updated", "Skill 'deploy-checklist' patched"). Shown
   * under the actions as one muted line, joined with " · ", after a bookmark
   * icon. Live only: a reply read from history has none.
   */
  reviewNotes?: string[];
  /**
   * `apple`: the copy, retry and edit buttons are 44x44px (the glyph stays 16px),
   * the iOS minimum tap target; text is 17px Body when the provider's ramp is
   * `ios`. Inherits the provider's platform.
   */
  platform?: Platform;
}

/**
 * The assistant's reply in a chat: bare Markdown prose with no bubble, then a
 * small row of actions (copy, try again, edit prompt) once it has finished,
 * an error note when it failed, and what Hermes saved after reading it.
 */
export function AssistantMessage({
  text,
  children,
  error,
  streaming = false,
  stopped = false,
  showCopy,
  copied = false,
  onCopy,
  onRetry,
  onEdit,
  reviewNotes,
  platform,
}: AssistantMessageProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const body = children ?? (text ? <Markdown source={text} /> : null);
  const copyVisible = showCopy ?? Boolean(text || children);
  const actionsVisible =
    !streaming && (copyVisible || Boolean(onRetry) || Boolean(onEdit) || stopped);
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div
        className={cx(
          "h-assistant-message",
          apple && "h-assistant-message--apple",
        )}
      >
        {body ? <div className="h-assistant-message__body">{body}</div> : null}
        {error ? (
          <div className="h-assistant-message__error" role="alert">
            <Icon name="error" size={16} />
            <span>{error}</span>
          </div>
        ) : null}
        {actionsVisible ? (
          <div className="h-assistant-message__actions">
            {stopped ? (
              <span className="h-assistant-message__stopped">
                <Icon name="stop_circle" size={16} />
                Stopped
              </span>
            ) : null}
            {copyVisible ? (
              <button
                type="button"
                className="h-assistant-message__action"
                aria-label={copied ? "Copied" : "Copy"}
                title={copied ? "Copied" : "Copy"}
                onClick={onCopy}
              >
                <Icon name={copied ? "check" : "content_copy"} size={16} />
              </button>
            ) : null}
            {onRetry ? (
              <button
                type="button"
                className="h-assistant-message__action"
                aria-label="Try again"
                title="Try again"
                onClick={onRetry}
              >
                <Icon name="refresh" size={16} />
              </button>
            ) : null}
            {onEdit ? (
              <button
                type="button"
                className="h-assistant-message__action"
                aria-label="Edit prompt"
                title="Edit prompt"
                onClick={onEdit}
              >
                <Icon name="edit" size={16} />
              </button>
            ) : null}
          </div>
        ) : null}
        {reviewNotes?.length ? (
          <div
            className="h-assistant-message__review"
            role="note"
            aria-label={`Hermes saved: ${reviewNotes.join(" · ")}`}
          >
            <Icon name="bookmark_added" size={16} />
            <span>{reviewNotes.join(" · ")}</span>
          </div>
        ) : null}
      </div>
    </PlatformScope>
  );
}

type Block =
  | { kind: "p"; text: string }
  | { kind: "h"; level: number; text: string }
  | { kind: "ul" | "ol"; items: string[] }
  | { kind: "code"; lang: string; code: string };

function parseBlocks(source: string): Block[] {
  const lines = source.replace(/\r\n/g, "\n").split("\n");
  const blocks: Block[] = [];
  let paragraph: string[] = [];
  const flush = () => {
    if (paragraph.length)
      blocks.push({ kind: "p", text: paragraph.join("\n") });
    paragraph = [];
  };
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const fence = line.match(/^\s*```(\S*)/);
    if (fence) {
      flush();
      const code: string[] = [];
      i++;
      while (i < lines.length && !/^\s*```/.test(lines[i]))
        code.push(lines[i++]);
      blocks.push({ kind: "code", lang: fence[1], code: code.join("\n") });
      continue;
    }
    const heading = line.match(/^(#{1,3})\s+(.*)$/);
    if (heading) {
      flush();
      blocks.push({ kind: "h", level: heading[1].length, text: heading[2] });
      continue;
    }
    const bullet = line.match(/^\s*[-*]\s+(.*)$/);
    const numbered = line.match(/^\s*\d+[.)]\s+(.*)$/);
    if (bullet || numbered) {
      flush();
      const kind = bullet ? "ul" : "ol";
      const item = (bullet ?? numbered)![1];
      const last = blocks[blocks.length - 1];
      if (last && last.kind === kind) last.items.push(item);
      else blocks.push({ kind, items: [item] });
      continue;
    }
    if (line.trim() === "") {
      flush();
      continue;
    }
    paragraph.push(line);
  }
  flush();
  return blocks;
}

const INLINE =
  /(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*\s][^*]*\*)|(\[[^\]]+\]\([^)\s]+\))|(https?:\/\/[^\s)]+)/g;

function renderInline(text: string): ReactNode[] {
  const out: ReactNode[] = [];
  let last = 0;
  let key = 0;
  for (const match of text.matchAll(INLINE)) {
    const index = match.index ?? 0;
    if (index > last) out.push(text.slice(last, index));
    const token = match[0];
    if (match[1]) {
      out.push(
        <code key={key++} className="h-assistant-message__inline-code">
          {token.slice(1, -1)}
        </code>,
      );
    } else if (match[2]) {
      out.push(<strong key={key++}>{renderInline(token.slice(2, -2))}</strong>);
    } else if (match[3]) {
      out.push(<em key={key++}>{renderInline(token.slice(1, -1))}</em>);
    } else if (match[4]) {
      const [, label, href] = token.match(/^\[([^\]]+)\]\(([^)]+)\)$/)!;
      out.push(
        <a key={key++} className="h-assistant-message__link" href={href}>
          {label}
        </a>,
      );
    } else {
      out.push(
        <a key={key++} className="h-assistant-message__link" href={token}>
          {token}
        </a>,
      );
    }
    last = index + token.length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

function Markdown({ source }: { source: string }) {
  return (
    <>
      {parseBlocks(source).map((block, i) => {
        switch (block.kind) {
          case "p":
            return <p key={i}>{renderInline(block.text)}</p>;
          case "h": {
            const Tag = `h${block.level + 2}` as "h3" | "h4" | "h5";
            return (
              <Tag
                key={i}
                className={`h-assistant-message__heading h-assistant-message__heading--${block.level}`}
              >
                {renderInline(block.text)}
              </Tag>
            );
          }
          case "ul":
          case "ol": {
            const List = block.kind;
            return (
              <List key={i}>
                {block.items.map((item, j) => (
                  <li key={j}>{renderInline(item)}</li>
                ))}
              </List>
            );
          }
          case "code":
            return (
              <div key={i} className="h-assistant-message__code">
                <div className="h-assistant-message__code-header">
                  <span className="h-assistant-message__code-lang">
                    <Icon name="terminal" apple={false} size={14} />
                    {block.lang || "Code"}
                  </span>
                  <button
                    type="button"
                    className="h-assistant-message__code-copy"
                    aria-label="Copy code"
                    title="Copy code"
                  >
                    <Icon name="content_copy" apple={false} size={18} />
                  </button>
                </div>
                <pre>
                  <code>{block.code}</code>
                </pre>
              </div>
            );
        }
      })}
    </>
  );
}
