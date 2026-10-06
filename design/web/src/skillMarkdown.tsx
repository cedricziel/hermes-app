import { AssistantMessage } from "./components/AssistantMessage/AssistantMessage";
import "./skillMarkdown.css";

/** The `SKILL.md` without its front matter, which renders as noise. */
export function skillMarkdownBody(text: string) {
  const match = /^---\s*\n[\s\S]*?\n---\s*(\n|$)/.exec(text);
  return match ? text.slice(match[0].length).trimStart() : text;
}

/**
 * A rendered `SKILL.md` (front matter stripped) at the width of its parent,
 * for the skill detail, hub skill and editor preview screens.
 */
export function SkillMarkdown({ text }: { text: string }) {
  return (
    <div className="h-skill-markdown">
      <AssistantMessage text={skillMarkdownBody(text)} showCopy={false} />
    </div>
  );
}
