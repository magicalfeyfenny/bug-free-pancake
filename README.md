# Containment Protocol

Containment Protocol is a playable first-person combat prototype for GameMaker
LTS 2026. The current run explores a deterministic six-space containment sector
with optional archive entries and deterministic supply caches, while preserving
WASD movement, mouse-look aiming, a four-role weapon arsenal, a pursuing
Chaser, an evasive Skirmisher with visible projectiles, health and damage,
victory and death, and restart controls.

Open [project/bugbugbug/bugbugbug.yyp](project/bugbugbug/bugbugbug.yyp) in
GameMaker to play. See [project/README.md](project/README.md) for controls and
the current gameplay and asset overview.

The repository also provides a governed workflow and machine-verifiable checks
for auditable agent changes, while humans retain authority over high-risk and
release decisions.

## Governance overview (non-normative)

This overview is navigation only. The authoritative workflow and rationale live
in [GOVERNANCE.md](GOVERNANCE.md#authority), executable values live in
[PROJECT_POLICY.toml](PROJECT_POLICY.toml), and task routing starts in
[AGENTS.md](AGENTS.md#authority-and-task-routing).

## What it provides

- the playable Containment Protocol project and its governed production routes;
- authoritative workflow rules in [GOVERNANCE.md](GOVERNANCE.md#authority);
- executable paths, asset formats, storage rules, and risk limits in
  [PROJECT_POLICY.toml](PROJECT_POLICY.toml);
- repository-policy, asset, storage, CI, and issue-contract tooling under
  [the tools directory](tools/setup_github.py);
- GitHub workflows, issue/PR support, and repository-local Codex skills and
  automation prompt templates; and
- adoption, policy-update, and resumable [setup](docs/SETUP.md) procedures.

Normal agent-governed work starts with one coherent implementation issue.
Broader requests split only when they contain independently meaningful
outcomes; technical implementation layers stay together when they jointly
deliver one outcome. Each issue branches from current `origin/dev`, uses an
issue-numbered branch, and opens a draft pull request after the first
meaningful, tested milestone. Blocked work waits until its blockers are
resolved.

Validation happens in three stages: focused checks support each milestone,
the complete change receives whole-issue local validation, and hosted CI then
verifies the exact pull-request head, body, labels, and accepted governing
issue revision. Completion metadata is added only after the whole change is
locally valid under that current issue contract.

Risk determines the final path. Eligible completed low- and medium-risk
work targeting `dev` can be marked ready and squash-merged by repository
automation after its evidence passes; completed medium-risk work also needs
focused change-specific machine-verifiable evidence. High-risk or manually
handled work remains on the human review, readiness, and merge path. High risk
requires a forced condition or a concrete structural or operational danger;
substantial ordinary gameplay and feature work can use medium risk. Completed
governed changes also pass the bounded adversarial review and adjudication
lifecycle before completion metadata is added.

`main` is release-only, and releases require explicit human authorization.
Human-created work uses a separate protected lane that agents do not modify.

## Start here

Use [project/README.md](project/README.md) to run the game. For repository
setup and maintenance, choose the route that matches the repository state:

- a valid GameMaker project with no meaningful governance uses the
  [greenfield setup](docs/SETUP.md);
- an existing repository with independent governance, earlier framework
  lineage, or uncertain history uses the read-only
  [brownfield adoption plan](docs/ADOPTION.md); and
- an already-adopted repository taking a newer upstream policy uses the
  [bounded policy-update procedure](docs/POLICY_UPDATE.md).

For day-to-day work, [AGENTS.md](AGENTS.md#authority-and-task-routing) routes
each task to only the governance sections and local skill it needs. High-risk
and manual-path review, readiness, and merge are authority gates; they do not
add manual, visual, live, or experiential validation unless the accepted issue
contract explicitly requires that judgment.
