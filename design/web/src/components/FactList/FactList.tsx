import { cx } from "../../platform";
import "./FactList.css";

/** One line of a `FactList`. */
export interface Fact {
  /** The muted label on the left: "type", "url", "command", "args". Empty for a continuation line (a second build step). */
  label: string;
  /** The value, in monospace. An array draws one line per entry (each argument, each variable name). */
  value: string | string[];
  /** Overrides the list's `mono` for this line: a cron expression among plain settings. */
  mono?: boolean;
}

export interface FactListProps {
  /** The facts, top to bottom. */
  facts: Fact[];
  /** Width of the label column in px: 92 in the install panel, 72 in the command review. */
  labelWidth?: number;
  /**
   * Values in monospace at 13px (default), for what Hermes runs or stores.
   * `false` sets labels and values in body text, for a job's settings
   * ("Deliver to", "Skills", "Model"); a single fact can still be `mono`.
   */
  mono?: boolean;
}

/**
 * Label and value lines that show exactly what Hermes will run or store: a
 * muted label column and monospace values that wrap anywhere (URLs, command
 * lines). Put it in a `Card` under a heading such as "What Hermes will run".
 * Same on every platform.
 */
export function FactList({
  facts,
  labelWidth = 92,
  mono = true,
}: FactListProps) {
  return (
    <dl className={cx("h-facts", !mono && "h-facts--plain")}>
      {facts.map((fact, i) => (
        <div key={i} className="h-facts__row">
          <dt className="h-facts__label" style={{ width: labelWidth }}>
            {fact.label}
          </dt>
          <dd
            className={cx(
              "h-facts__value",
              (fact.mono ?? mono) && "h-facts__value--mono",
            )}
          >
            {(Array.isArray(fact.value) ? fact.value : [fact.value]).map(
              (line, j) => (
                <div key={j}>{line}</div>
              ),
            )}
          </dd>
        </div>
      ))}
    </dl>
  );
}
