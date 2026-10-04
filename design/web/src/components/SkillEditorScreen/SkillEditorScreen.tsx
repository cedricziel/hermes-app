import { AssistantMessage } from "../AssistantMessage/AssistantMessage";
import { Button } from "../Button/Button";
import { IconButton } from "../IconButton/IconButton";
import { SegmentedControl } from "../SegmentedControl/SegmentedControl";
import { Spinner } from "../Spinner/Spinner";
import { TextField } from "../TextField/TextField";
import { ScreenFrame, type ScreenLayout } from "../../screenFrame";
import { usePlatform, type AppleDevice, type Platform } from "../../platform";
import "./SkillEditorScreen.css";

/** The `SKILL.md` a new skill starts from. */
export const newSkillTemplate = `---
name:
description:
---

# Title

When to use this skill, and what to do.
`;

/** Markdown the format toolbar inserts at the cursor. */
export type SkillSnippet = "heading" | "bold" | "bullet" | "code";

export interface SkillEditorScreenProps {
  /** `create`: "New skill" with Name and Category fields above the text. `edit`: "Edit <name>". */
  mode: "create" | "edit";
  /** The skill being edited (`edit`), shown in the title. */
  name?: string;
  /** The `SKILL.md` text, front matter included. Defaults to the new skill template. */
  text?: string;
  /** `create`: the Name field's value. Save stays off until it has one. */
  nameValue?: string;
  /** `create`: the "Category (optional)" field's value. */
  category?: string;
  /** `edit` shows the monospace text with the format toolbar under it; `preview` renders the Markdown without its front matter. */
  view?: "edit" | "preview";
  /** Save is enabled: the text changed and, when creating, there is a name. */
  canSave?: boolean;
  /** The save is in flight: a small spinner replaces "Save". */
  saving?: boolean;
  /** Why the last save failed, in red above the text. The text stays as it is. */
  error?: string;
  /** Undo and redo are available (the toolbar's arrows). */
  canUndo?: boolean;
  canRedo?: boolean;
  onClose?: () => void;
  onSave?: () => void;
  onViewChange?: (view: "edit" | "preview") => void;
  onTextChange?: (text: string) => void;
  onNameChange?: (name: string) => void;
  onCategoryChange?: (category: string) => void;
  /** A toolbar button was pressed: `#`, `**`, `•` or `</>`. */
  onInsert?: (snippet: SkillSnippet) => void;
  onUndo?: () => void;
  onRedo?: () => void;
  /** `phone` or `desktop` (a Mac window or a Material desktop). The editor fills the width on both. */
  layout?: ScreenLayout;
  /**
   * `apple`: the 44px bar (52px Mac toolbar on `desktop`), the iOS segmented
   * control for Edit and Preview, and Apple spinners. Material keeps the
   * underline tabs. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

const snippets: { id: SkillSnippet; label: string; name: string }[] = [
  { id: "heading", label: "#", name: "Heading" },
  { id: "bold", label: "**", name: "Bold" },
  { id: "bullet", label: "•", name: "Bullet" },
  { id: "code", label: "</>", name: "Code block" },
];

function markdownBody(text: string) {
  const match = /^---\s*\n[\s\S]*?\n---\s*(\n|$)/.exec(text);
  return match ? text.slice(match[0].length).trimStart() : text;
}

/**
 * Writes a new skill or edits one's `SKILL.md`, full screen: a close (X)
 * button and Save in the bar, Name and Category when creating, an Edit and
 * Preview switch, a monospace editor that fills the screen and a format
 * toolbar (heading, bold, bullet, code block, undo, redo) under it. Leaving
 * with unsaved changes asks first in the app (not drawn). Built from
 * `ListDetailLayout` (`onClose`), `TextField`, `SegmentedControl` and
 * `AssistantMessage` for the preview.
 */
export function SkillEditorScreen({
  mode,
  name,
  text = newSkillTemplate,
  nameValue = "",
  category = "",
  view = "edit",
  canSave = false,
  saving = false,
  error,
  canUndo = false,
  canRedo = false,
  onClose,
  onSave,
  onViewChange,
  onTextChange,
  onNameChange,
  onCategoryChange,
  onInsert,
  onUndo,
  onRedo,
  layout = "phone",
  platform,
  device,
}: SkillEditorScreenProps) {
  const resolved = usePlatform(platform);
  const editing = view === "edit";
  return (
    <ScreenFrame
      title={mode === "create" ? "New skill" : `Edit ${name ?? ""}`}
      onClose={onClose}
      actions={
        <Button
          variant="text"
          disabled={!canSave || saving}
          onClick={onSave}
          aria-label="Save"
        >
          {saving ? <Spinner size={18} label="Saving" /> : "Save"}
        </Button>
      }
      layout={layout}
      platform={resolved}
      device={device}
      maxWidth={null}
      footer={
        editing ? (
          <div className="h-skill-editor__toolbar">
            {snippets.map((s) => (
              <span key={s.id} className="h-skill-editor__snippet">
                <Button
                  variant="text"
                  fullWidth
                  aria-label={s.name}
                  onClick={() => onInsert?.(s.id)}
                >
                  {s.label}
                </Button>
              </span>
            ))}
            <IconButton
              icon="undo"
              label="Undo"
              disabled={!canUndo}
              onClick={onUndo}
            />
            <IconButton
              icon="redo"
              label="Redo"
              disabled={!canRedo}
              onClick={onRedo}
            />
          </div>
        ) : undefined
      }
    >
      <div className="h-skill-editor">
        {mode === "create" ? (
          <div className="h-skill-editor__fields">
            <TextField
              label="Name"
              value={nameValue}
              placeholder="web-research"
              onChange={(e) => onNameChange?.(e.target.value)}
            />
            <TextField
              label="Category (optional)"
              value={category}
              placeholder="research"
              onChange={(e) => onCategoryChange?.(e.target.value)}
            />
          </div>
        ) : null}
        <div className="h-skill-editor__switch">
          <SegmentedControl
            labels={["Edit", "Preview"]}
            value={editing ? 0 : 1}
            onChange={(i) => onViewChange?.(i === 0 ? "edit" : "preview")}
            label="View"
          />
        </div>
        {error ? (
          <div className="h-body-md h-skill-editor__error" role="alert">
            {error}
          </div>
        ) : null}
        {editing ? (
          <TextField
            className="h-skill-editor__text"
            aria-label="SKILL.md"
            rows={12}
            mono
            spellCheck={false}
            value={text}
            onChange={(e) => onTextChange?.(e.target.value)}
          />
        ) : (
          <div className="h-skill-editor__preview">
            <AssistantMessage text={markdownBody(text)} showCopy={false} />
          </div>
        )}
      </div>
    </ScreenFrame>
  );
}
