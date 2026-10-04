import { AssistantMessage } from "../AssistantMessage/AssistantMessage";
import { Badge } from "../Badge/Badge";
import { Button } from "../Button/Button";
import { Card } from "../Card/Card";
import { Chip } from "../Chip/Chip";
import { skillSourceLabels, type Skill } from "../SkillRow/SkillRow";
import { Spinner } from "../Spinner/Spinner";
import { SwitchRow } from "../SwitchRow/SwitchRow";
import { ScreenFrame, type ScreenLayout } from "../../screenFrame";
import { usePlatform, type AppleDevice, type Platform } from "../../platform";
import "./SkillDetailScreen.css";

/** The `SKILL.md` without its front matter, which renders as noise. */
export function skillMarkdownBody(text: string) {
  const match = /^---\s*\n[\s\S]*?\n---\s*(\n|$)/.exec(text);
  return match ? text.slice(match[0].length).trimStart() : text;
}

export interface SkillDetailScreenProps {
  /** The skill. Leave out when it no longer exists ("This skill no longer exists."). */
  skill?: Skill;
  /** Name for the title when `skill` is gone. */
  name?: string;
  /** Its `SKILL.md`, front matter included (stripped before rendering). */
  content?: string;
  /** The `SKILL.md` content: `loaded` (default), `loading` (a spinner) or `failed` ("Could not load this skill" with Retry). */
  contentState?: "loaded" | "loading" | "failed";
  /** A skills hub is connected: a hub skill offers Uninstall. */
  hub?: boolean;
  /** A hub job is running: Uninstall is disabled. */
  hubBusy?: boolean;
  onBack?: () => void;
  onEnabledChange?: (enabled: boolean) => void;
  /** Agent skills: Edit (opens `SkillEditorScreen`). */
  onEdit?: () => void;
  /** Agent skills: "Ask agent to delete" drafts a chat message (the server cannot delete skills). */
  onAskDelete?: () => void;
  /** Hub skills: Uninstall (confirmed, then a `SkillJobSheet`). */
  onUninstall?: () => void;
  onRetry?: () => void;
  /** `phone` or `desktop`; the content stays in a 720px column. */
  layout?: ScreenLayout;
  /** `apple`: chevron back with "Skills", the Apple toggle and spinner. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * One installed skill, pushed from the Skills screen: its category, source
 * and usage, an Enabled `SwitchRow`, the actions its source allows (Edit and
 * "Ask agent to delete" for an agent skill, Uninstall for a hub skill, a
 * note for a bundled one), and its rendered `SKILL.md` in a `Card`.
 */
export function SkillDetailScreen({
  skill,
  name,
  content = "",
  contentState = "loaded",
  hub = false,
  hubBusy = false,
  onBack,
  onEnabledChange,
  onEdit,
  onAskDelete,
  onUninstall,
  onRetry,
  layout = "phone",
  platform,
  device,
}: SkillDetailScreenProps) {
  const resolved = usePlatform(platform);
  const danger = { color: "var(--h-error)" };
  return (
    <ScreenFrame
      title={skill?.name ?? name ?? ""}
      onBack={onBack}
      backLabel="Skills"
      layout={layout}
      platform={resolved}
      device={device}
      maxWidth={720}
      centered={!skill}
    >
      {!skill ? (
        <div className="h-body-md">This skill no longer exists.</div>
      ) : (
        <div className="h-skill-detail">
          <div className="h-skill-detail__facts">
            {skill.category ? <Chip label={skill.category} /> : null}
            <Badge>{skillSourceLabels[skill.source]}</Badge>
            {skill.usage ? (
              <span className="h-body-md">used {skill.usage}×</span>
            ) : null}
          </div>
          <SwitchRow
            title="Enabled"
            subtitle="The agent may load this skill"
            checked={skill.enabled}
            onChange={onEnabledChange}
          />
          {skill.source === "agent" ? (
            <div className="h-skill-detail__actions">
              <Button
                icon="edit"
                disabled={contentState !== "loaded"}
                onClick={onEdit}
              >
                Edit
              </Button>
              <Button variant="outlined" style={danger} onClick={onAskDelete}>
                Ask agent to delete
              </Button>
            </div>
          ) : skill.source === "hub" && hub ? (
            <div className="h-skill-detail__actions">
              <Button
                variant="outlined"
                style={hubBusy ? undefined : danger}
                disabled={hubBusy}
                onClick={onUninstall}
              >
                Uninstall
              </Button>
            </div>
          ) : (
            <div className="h-body-sm h-skill-detail__note">
              Bundled and hub skills can only be switched on or off here.
            </div>
          )}
          <div className="h-skill-detail__content">
            {contentState === "failed" ? (
              <div className="h-skill-detail__failed">
                <div className="h-body-md">Could not load this skill</div>
                <Button onClick={onRetry}>Retry</Button>
              </div>
            ) : contentState === "loading" ? (
              <div className="h-skill-detail__failed">
                <Spinner size={36} label="Loading the skill" />
              </div>
            ) : (
              <Card>
                <AssistantMessage
                  text={skillMarkdownBody(content)}
                  showCopy={false}
                />
              </Card>
            )}
          </div>
        </div>
      )}
    </ScreenFrame>
  );
}
