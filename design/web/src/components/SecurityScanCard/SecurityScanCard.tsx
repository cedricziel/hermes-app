import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { Spinner } from "../Spinner/Spinner";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "./SecurityScanCard.css";

/** What the server's install policy says after a scan. */
export type InstallPolicy = "allow" | "ask" | "block";

/** One thing the security scan found in a hub skill. */
export interface ScanFinding {
  /** "critical", "high", "medium" or "low"; shown upper-case before the description. */
  severity: string;
  /** What it found: "Downloads and runs a remote script". */
  description: string;
  /** File inside the skill, e.g. "scripts/fetch.sh". */
  file?: string;
  /** Line in that file. */
  line?: number;
}

export interface SecurityScanCardProps {
  /** `running`: the scan is still going (a spinner row). `failed`: it could not run (a Retry button). `done`: the verdict and findings. */
  state: "running" | "failed" | "done";
  /** Verdict when `done`: `allow` "Passed" (primary), `ask` "Caution: confirmation required" (warning), `block` "Blocked" (error). Absent or unknown policy is blocked. */
  policy?: InstallPolicy;
  /** One line under the verdict: "1 finding". */
  summary?: string;
  /** Findings per severity, e.g. `{ medium: 1 }`; each non-zero count is text ("1 medium"). */
  severityCounts?: Record<string, number>;
  /** Why the policy blocks the install; shown in the verdict color only for `block`. */
  policyReason?: string;
  /** Each finding, below a divider: severity and description, then file:line in monospace. */
  findings?: ScanFinding[];
  /** Retry was pressed in the `failed` state. */
  onRetry?: () => void;
  /** Spinner and buttons follow it. Inherits the provider's platform. */
  platform?: Platform;
}

const verdicts: Record<InstallPolicy, string> = {
  allow: "Passed",
  ask: "Caution: confirmation required",
  block: "Blocked",
};

/**
 * The security scan of a skill from the hub, as the hub skill screen shows it
 * before anything is installed: running, failed with Retry, or the verdict
 * with severity counts and the findings. Fills its parent's width.
 */
export function SecurityScanCard({
  state,
  policy = "block",
  summary,
  severityCounts = {},
  policyReason,
  findings = [],
  onRetry,
  platform,
}: SecurityScanCardProps) {
  const resolved = usePlatform(platform);
  if (state === "running") {
    return <GroupedSection header="Security scan" platform={resolved}>
      <GroupedRow title="Running the security scan…" chevron={false}
        trailing={<Spinner size={20} label="Scanning" />} />
    </GroupedSection>;
  }
  if (state === "failed") {
    return <GroupedSection header="Security scan" platform={resolved}>
      <GroupedRow title="Could not run the security scan." chevron={false} />
      <GroupedRow title="Retry" chevron={false} onClick={onRetry} />
    </GroupedSection>;
  }
  const safePolicy = policy === "allow" || policy === "ask" ? policy : "block";
  const counts = Object.entries(severityCounts).filter(([, n]) => n > 0);
  return (
    <PlatformScope platform={resolved}>
      <GroupedSection header="Security scan">
        <div className={`h-scan-card h-scan-card--${safePolicy}`}>
          <div className="h-scan-card__verdict">{verdicts[safePolicy]}</div>
          {summary ? <div className="h-body-md">{summary}</div> : null}
          {counts.length > 0 ? (
            <div className="h-scan-card__counts">
              {counts.map(([severity, n]) => (
                <span key={severity} className="h-scan-card__count">
                  {n} {severity}
                </span>
              ))}
            </div>
          ) : null}
          {safePolicy === "block" && policyReason ? (
            <div className="h-body-md h-scan-card__reason">{policyReason}</div>
          ) : null}
          {findings.map((f, i) => {
            const where = [f.file, f.line?.toString()].filter(Boolean).join(":");
            return (
              <div key={i} className="h-scan-card__finding">
                <div className="h-body-md">
                  <span className="h-scan-card__severity">
                    {f.severity.toUpperCase()}
                  </span>
                  {f.description}
                </div>
                {where ? (
                  <div className="h-mono h-scan-card__where">{where}</div>
                ) : null}
              </div>
            );
          })}
        </div>
      </GroupedSection>
    </PlatformScope>
  );
}
