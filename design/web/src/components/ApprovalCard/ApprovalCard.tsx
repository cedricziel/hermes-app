import type { ReactNode } from "react";
import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import "./ApprovalCard.css";

/** Where an agent input request stands. */
export type InputRequestStatus = "pending" | "answered" | "expired";

/** An answer Hermes accepts for an approval. */
export type ApprovalChoice = "once" | "session" | "always" | "deny";

const labels: Record<ApprovalChoice, string> = {
  once: "Allow once",
  session: "Allow for session",
  always: "Always allow",
  deny: "Deny",
};

const outcomes: Record<ApprovalChoice, string> = {
  once: "Allowed once",
  session: "Allowed for this session",
  always: "Always allowed",
  deny: "Denied",
};

export interface InputCardFrameProps {
  /** Material Symbols icon name shown before the title (16px, primary color). */
  icon: string;
  /** Bold title, such as "Approval needed" or "Hermes has a question". */
  title: string;
  /** The card's content below the title. */
  children?: ReactNode;
  className?: string;
}

/** The bordered, faintly tinted surface that approval, clarify and other agent input requests share. Use it for a new kind of request card. */
export function InputCardFrame({
  icon,
  title,
  children,
  className,
}: InputCardFrameProps) {
  return (
    <div className={["h-input-card", className].filter(Boolean).join(" ")}>
      <div className="h-input-card__header">
        <Icon name={icon} size={16} className="h-input-card__icon" />
        <span className="h-input-card__title">{title}</span>
      </div>
      {children}
    </div>
  );
}

export interface InputCardNoteProps {
  /** The one-line status: an outcome, a timeout or an error. */
  children: ReactNode;
  /** Red error text instead of muted. */
  error?: boolean;
}

/** A one-line muted (or red) status under an input request card's content. */
export function InputCardNote({ children, error = false }: InputCardNoteProps) {
  return (
    <div
      className={[
        "h-input-card__note",
        error ? "h-input-card__note--error" : null,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      {children}
    </div>
  );
}

export interface ApprovalCardProps {
  /** What the agent wants to do, in a sentence ("Delete the build folder"). */
  description?: string;
  /** The exact command it wants to run, shown in a monospace box. */
  command?: string;
  /** Answers to offer, in order. Defaults to Allow once and Deny. */
  choices?: ApprovalChoice[];
  /** `pending` shows the buttons; `answered` and `expired` replace them with the outcome. */
  status?: InputRequestStatus;
  /** The answer given, for the `answered` state. */
  choice?: ApprovalChoice;
  /** Disables the buttons while an answer is being sent, or when there is no way to answer. */
  disabled?: boolean;
  /** Error shown under the buttons when sending an answer failed. */
  error?: string;
  /** Called with the picked answer. The app asks for confirmation before sending `always`. */
  onAnswer?: (choice: ApprovalChoice) => void;
  className?: string;
}

/** The agent wants to run something and waits for the user to allow or deny it. Shown inside the ToolCallCard of the call it holds up; once answered or expired the buttons give way to the outcome. */
export function ApprovalCard({
  description,
  command,
  choices,
  status = "pending",
  choice,
  disabled = false,
  error,
  onAnswer,
  className,
}: ApprovalCardProps) {
  const offered: ApprovalChoice[] =
    choices && choices.length ? choices : ["once", "deny"];
  return (
    <InputCardFrame
      icon="shield"
      title="Approval needed"
      className={["h-approval-card", className].filter(Boolean).join(" ")}
    >
      {description ? (
        <p className="h-approval-card__description">{description}</p>
      ) : null}
      {command ? (
        <div className="h-approval-card__command">{command}</div>
      ) : null}
      <div className="h-approval-card__gap" />
      {status === "pending" ? (
        <div className="h-approval-card__actions">
          {offered.map((c) => (
            <Button
              key={c}
              variant={
                c === "once" ? "filled" : c === "deny" ? "text" : "outlined"
              }
              disabled={disabled || !onAnswer}
              onClick={() => onAnswer?.(c)}
            >
              {labels[c]}
            </Button>
          ))}
        </div>
      ) : status === "answered" ? (
        <InputCardNote>{choice ? outcomes[choice] : "Answered"}</InputCardNote>
      ) : (
        <InputCardNote>This request timed out</InputCardNote>
      )}
      {error && status === "pending" ? (
        <InputCardNote error>{error}</InputCardNote>
      ) : null}
    </InputCardFrame>
  );
}
