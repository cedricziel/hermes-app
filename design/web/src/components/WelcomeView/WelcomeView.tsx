import { Icon } from "../Icon/Icon";
import "./WelcomeView.css";

/** Where a starter prompt came from; it picks the card's icon. */
export type StarterSource =
  "generic" | "schedule" | "kanban" | "chat" | "skill";

/** One starter prompt card on the welcome view. */
export interface StarterPromptItem {
  /**
   * The prompt. One left open for the user to finish ends in a space
   * ("Use the release-notes skill to ") and is shown with "…".
   */
  text: string;
  /**
   * `schedule`: a failed scheduled job (clock). `kanban`: a blocked or
   * in-review task (board). `chat`: the latest chat (bubble). `skill`: the
   * most-used skill (puzzle piece). `generic` (default): lightbulb.
   */
  source?: StarterSource;
}

/** The four generic prompts the app pads with when the server offers no context. */
export const GENERIC_STARTER_PROMPTS: StarterPromptItem[] = [
  { text: "What can you help me with?" },
  { text: "Which skills and tools can you use?" },
  { text: "Draft a status update for the team" },
  { text: "Help me think through a problem" },
];

const icons: Record<StarterSource, string> = {
  generic: "lightbulb",
  schedule: "schedule",
  kanban: "view_kanban",
  chat: "chat_bubble",
  skill: "extension",
};

export interface WelcomeViewProps {
  /** First name for "Where should we begin, Ada?"; without it, "Where should we begin?". */
  greetingName?: string | null;
  /** The starter prompt cards, normally four: context ones first, then generic ones. */
  prompts?: StarterPromptItem[];
  /** Room left at the bottom for whatever overlays it (the composer), in px. */
  bottomPadding?: number;
  /** A starter prompt card was clicked. */
  onPick?: (prompt: StarterPromptItem) => void;
}

/**
 * The empty-chat state: a sparkle tile, "Where should we begin?", a subtitle
 * and a grid of starter prompt cards, centred in the space above the
 * composer. Cards sit two to a row (290px each) and stack below 590px.
 */
export function WelcomeView({
  greetingName,
  prompts = GENERIC_STARTER_PROMPTS,
  bottomPadding = 0,
  onPick,
}: WelcomeViewProps) {
  const greeting = greetingName
    ? `Where should we begin, ${greetingName}?`
    : "Where should we begin?";
  return (
    <div className="h-welcome-view" style={{ paddingBottom: bottomPadding }}>
      <div className="h-welcome-view__column">
        <div className="h-welcome-view__tile">
          <Icon name="auto_awesome" filled size={20} />
        </div>
        <h2 className="h-welcome-view__greeting">{greeting}</h2>
        <p className="h-welcome-view__subtitle">
          Ask Hermes Agent about your server, your codebase, or anything it has
          tools for.
        </p>
        <div className="h-welcome-view__grid">
          {prompts.map((p) => (
            <button
              key={p.text}
              type="button"
              className="h-welcome-view__card"
              onClick={() => onPick?.(p)}
            >
              <Icon
                name={icons[p.source ?? "generic"]}
                size={16}
                className="h-welcome-view__card-icon"
              />
              <span className="h-welcome-view__card-text">
                {p.text.endsWith(" ") ? `${p.text.trimEnd()}…` : p.text}
              </span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
