import { Button } from "../Button/Button";
import { Card } from "../Card/Card";
import { SectionHeader } from "../SectionHeader/SectionHeader";
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
  /** Verdict when `done`: `allow` "Passed" (primary), `ask` "Caution: confirmation required" (warning), `block` "Blocked" (error). Tints the border too. */
  policy?: InstallPolicy;
  /** One line under the verdict: "1 finding". */
  summary?: string;
  /** Findings per severity, e.g. `{ medium: 1 }`; each non-zero count is a chip ("1 medium"). */
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
 * with severity chips and the findings. Fills its parent's width.
 */
export function SecurityScanCard({
  state,
  policy = "allow",
  summary,
  severityCounts = {},
  policyReason,
  findings = [],
  onRetry,
  platform,
}: SecurityScanCardProps) {
  const resolved = usePlatform(platform);
  if (state === "running") {
    return (
      <PlatformScope platform={resolved}>
        <Card
          className="h-scan-card h-scan-card--running"
          style={{ padding: "8px 16px" }}
        >
          <Spinner size={20} label="Scanning" />
          <span className="h-body-lg">Running the security scan…</span>
        </Card>
      </PlatformScope>
    );
  }
  if (state === "failed") {
    return (
      <PlatformScope platform={resolved}>
        <Card className="h-scan-card">
          <div className="h-body-md">Could not run the security scan.</div>
          <div className="h-scan-card__retry">
            <Button onClick={onRetry}>Retry</Button>
          </div>
        </Card>
      </PlatformScope>
    );
  }
  const counts = Object.entries(severityCounts).filter(([, n]) => n > 0);
  return (
    <PlatformScope platform={resolved}>
      <Card className={`h-scan-card h-scan-card--${policy}`}>
        <SectionHeader title="Security scan" variant="overline" />
        <div className="h-scan-card__verdict">{verdicts[policy]}</div>
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
        {policy === "block" && policyReason ? (
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
      </Card>
    </PlatformScope>
  );
}
