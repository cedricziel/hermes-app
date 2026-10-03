import { useState } from "react";
import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { TextField } from "../TextField/TextField";
import {
  InputCardFrame,
  InputCardNote,
  type InputRequestStatus,
} from "../ApprovalCard/ApprovalCard";
import "./ClarifyCard.css";

/** One question the agent asks. */
export interface ClarifyQuestion {
  /** Key the answer is sent under. */
  id: string;
  /** The question itself. */
  question: string;
  /** Options to pick from as chips. Without any, the question gets a free-text field. */
  choices?: string[];
  /** Lets the user pick several choices instead of one. */
  multiSelect?: boolean;
}

export interface ClarifyCardProps {
  /** The questions, one or a batch, answered together. */
  questions: ClarifyQuestion[];
  /** A batch of questions sends with "Confirm" instead of "Send". */
  batch?: boolean;
  /** `pending` takes answers; `answered` lists them; `expired` says the request timed out. */
  status?: InputRequestStatus;
  /** Answers by question id: for `answered` the ones given (empty means skipped), for `pending` the initial picks and text. */
  answers?: Record<string, string[]>;
  /** Disables the controls while answers are being sent, or when there is no way to answer. */
  disabled?: boolean;
  /** Error shown under the buttons when sending failed. */
  error?: string;
  /** Called with the answers by question id when Send or Confirm is pressed; an empty object means Skip. */
  onAnswer?: (answers: Record<string, string[]>) => void;
  className?: string;
}

/** The agent asks one question or a batch and waits: choice chips or a text field per question, then Send (or Confirm) and Skip. Answers stay on the card until sent, so a batch goes out together. */
export function ClarifyCard({
  questions,
  batch = false,
  status = "pending",
  answers,
  disabled = false,
  error,
  onAnswer,
  className,
}: ClarifyCardProps) {
  const [picked, setPicked] = useState<Record<string, string[]>>(() =>
    status === "pending" ? (answers ?? {}) : {},
  );
  const enabled = !disabled && !!onAnswer;
  const answerFor = (q: ClarifyQuestion) =>
    (picked[q.id] ?? []).map((a) => a.trim()).filter(Boolean);
  const ready = questions.every((q) => answerFor(q).length > 0);

  const toggle = (q: ClarifyQuestion, choice: string) =>
    setPicked((now) => {
      const current = now[q.id] ?? [];
      if (!q.multiSelect) return { ...now, [q.id]: [choice] };
      return {
        ...now,
        [q.id]: current.includes(choice)
          ? current.filter((c) => c !== choice)
          : [...current, choice],
      };
    });

  const body = () => {
    if (status === "expired")
      return <InputCardNote>This request timed out</InputCardNote>;
    if (status === "answered") {
      const given = answers ?? {};
      if (Object.keys(given).length === 0)
        return <InputCardNote>Skipped</InputCardNote>;
      return (
        <div className="h-clarify-card__answers">
          {questions.map((q) => (
            <div key={q.id}>
              <div className="h-clarify-card__question">{q.question}</div>
              <InputCardNote>{(given[q.id] ?? []).join(", ")}</InputCardNote>
            </div>
          ))}
        </div>
      );
    }
    return (
      <>
        {questions.map((q) => (
          <div key={q.id} className="h-clarify-card__item">
            <div className="h-clarify-card__question">{q.question}</div>
            {q.choices && q.choices.length ? (
              <div className="h-clarify-card__choices">
                {q.choices.map((c) => (
                  <Chip
                    key={c}
                    label={c}
                    selected={(picked[q.id] ?? []).includes(c)}
                    disabled={disabled}
                    onClick={() => toggle(q, c)}
                  />
                ))}
              </div>
            ) : (
              <TextField
                placeholder="Type your answer"
                disabled={disabled}
                value={(picked[q.id] ?? [])[0] ?? ""}
                onChange={(e) =>
                  setPicked((now) => ({ ...now, [q.id]: [e.target.value] }))
                }
              />
            )}
          </div>
        ))}
        <div className="h-clarify-card__actions">
          <Button
            disabled={!enabled || !ready}
            onClick={() =>
              onAnswer?.(
                Object.fromEntries(questions.map((q) => [q.id, answerFor(q)])),
              )
            }
          >
            {batch ? "Confirm" : "Send"}
          </Button>
          <Button
            variant="text"
            disabled={!enabled}
            onClick={() => onAnswer?.({})}
          >
            Skip
          </Button>
        </div>
        {error ? <InputCardNote error>{error}</InputCardNote> : null}
      </>
    );
  };

  return (
    <InputCardFrame
      icon="help"
      title="Hermes has a question"
      className={["h-clarify-card", className].filter(Boolean).join(" ")}
    >
      {body()}
    </InputCardFrame>
  );
}
