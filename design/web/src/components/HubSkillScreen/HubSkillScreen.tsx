import { Badge } from "../Badge/Badge";
import { Button } from "../Button/Button";
import { hubTrustLabels, type HubSkill } from "../HubSkillRow/HubSkillRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import {
  SecurityScanCard,
  type SecurityScanCardProps,
} from "../SecurityScanCard/SecurityScanCard";
import { SkillMarkdown } from "../../skillMarkdown";
import { type ScreenLayout } from "../../screenFrame";
import type { AppleDevice, Platform } from "../../platform";
import "./HubSkillScreen.css";

export interface HubSkillScreenProps {
  /** The hub skill. */
  skill: HubSkill;
  /** Where it comes from, shown as text: "github", "official". */
  source?: string;
  /** The preview of its contents: `loading` (default while it loads, nothing drawn), `loaded` (file list and rendered `SKILL.md`), `failed` ("Could not load the skill's contents."). */
  previewState?: "loading" | "loaded" | "failed";
  /** Its files, from the preview: "SKILL.md", "scripts/fetch.sh". Adds an "N files" label. */
  files?: string[];
  /** Its `SKILL.md`, from the preview. */
  markdown?: string;
  /** The server's security scan, which runs when the screen opens: `state` running, failed (Retry) or done with a policy. Decides the install button. */
  scan: Omit<SecurityScanCardProps, "onRetry" | "platform">;
  /** Already installed: a disabled "Installed" button. */
  installed?: boolean;
  /** A hub job is running: the install button is disabled. */
  busy?: boolean;
  onBack?: () => void;
  /** Install (policy `allow`). */
  onInstall?: () => void;
  /** "Install anyway…" (policy `ask`); the app confirms with the findings first. */
  onInstallAnyway?: () => void;
  /** Retry after the scan failed. */
  onRetry?: () => void;
  /** `phone` or `desktop`; the content uses the grouped platform column. */
  layout?: ScreenLayout;
  /** `apple`: chevron back with "Skills", Apple spinner. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * A skill on the hub before it is installed, pushed from the Discover tab:
 * description, trust badge and source, the `SecurityScanCard`, its files and
 * rendered `SKILL.md`, and an install button pinned at the bottom that
 * follows the scan's policy: Install for `allow`, "Install anyway…" with a
 * caption for `ask`, disabled with "Blocked by the server's policy." for
 * `block`.
 */
export function HubSkillScreen({
  skill,
  source,
  previewState = "loading",
  files = [],
  markdown = "",
  scan,
  installed = false,
  busy = false,
  onBack,
  onInstall,
  onInstallAnyway,
  onRetry,
  layout = "phone",
  platform,
  device,
}: HubSkillScreenProps) {
  const done = scan.state === "done";
  const policy =
    scan.policy === "allow" || scan.policy === "ask" ? scan.policy : "block";
  // The install button follows the scan's policy, as hub_skill_screen.dart.
  const action = installed
    ? { label: "Installed" }
    : !done
      ? { label: "Install" }
      : policy === "allow"
        ? { label: "Install", onClick: onInstall, enabled: !busy }
        : policy === "ask"
          ? {
              label: "Install anyway…",
              outlined: true,
              onClick: onInstallAnyway,
              enabled: !busy,
              caption: "Server policy: ask. You will be asked to confirm.",
            }
          : { label: "Install", caption: "Blocked by the server's policy." };
  const loaded = previewState === "loaded";
  return (
    <SettingsScaffold
      title={skill.name}
      onBack={onBack}
      backLabel="Skills"
      platform={platform}
      device={layout === "phone" ? "touch" : (device ?? "mac")}
    >
      <GroupedListView>
        <div className="h-hub-skill">
          {skill.description ? (
            <div className="h-body-md">{skill.description}</div>
          ) : null}
          <div className="h-hub-skill__facts">
            <Badge tone={skill.trust === "builtin" ? "strong" : "neutral"}>
              {hubTrustLabels[skill.trust]}
            </Badge>
            {source ? <span>{source}</span> : null}
            {loaded ? <span>{files.length} files</span> : null}
          </div>
          <SecurityScanCard {...scan} policy={policy} onRetry={onRetry} />
          {previewState === "failed" ? (
            <div className="h-body-md">Could not load the skill's contents.</div>
          ) : null}
          {loaded && files.length > 0 ? (
            <GroupedSection header="Files">
              <div className="h-mono h-hub-skill__files">
                {files.map((f) => (
                  <div key={f}>{f}</div>
                ))}
              </div>
            </GroupedSection>
          ) : null}
          {loaded ? (
            <GroupedSection>
              <div className="h-hub-skill__markdown">
                <SkillMarkdown text={markdown} />
              </div>
            </GroupedSection>
          ) : null}
        </div>
      </GroupedListView>
      <div className="h-hub-skill__bottom">
        <Button
          fullWidth
          variant={action.outlined ? "outlined" : "filled"}
          disabled={!action.enabled}
          onClick={action.onClick}
        >
          {action.label}
        </Button>
        {action.caption ? (
          <div className="h-body-sm h-muted">{action.caption}</div>
        ) : null}
      </div>
    </SettingsScaffold>
  );
}
