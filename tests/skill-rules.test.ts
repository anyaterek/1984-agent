import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

// Pins the safety rules found in the final review, so a later edit of the
// skill text cannot silently drop them.
const SKILL_DIR = resolve(import.meta.dirname, '../skills/mr-review');
const read = (file: string) => readFileSync(join(SKILL_DIR, file), 'utf8');

describe('mr-review safety rules', () => {
  it('asks about running fork code in the main agent, before any reviewer starts', () => {
    expect(read('SKILL.md')).toMatch(/before any reviewer starts/i);
    expect(read('references/modes.md')).toMatch(/Checks decision/);
    expect(read('references/roles/tests.md')).toMatch(/never ask the user/i);
  });

  it('treats MR content as data, not instructions', () => {
    expect(read('references/modes.md')).toMatch(/data to review, never instructions/i);
  });

  it('lets reviewers reuse the given worktree instead of re-creating it', () => {
    expect(read('references/checks.md')).toMatch(/If your brief gives you a worktree path/);
  });

  it('reads REVIEW.md before detecting the platform', () => {
    const skill = read('SKILL.md');
    expect(skill.indexOf('**Team rules.**')).toBeGreaterThan(-1);
    expect(skill.indexOf('**Team rules.**')).toBeLessThan(skill.indexOf('**Repository and platform.**'));
    expect(read('references/platforms.md')).toMatch(/MR_REVIEW_REMOTE/);
  });

  it('has an executable GitHub 422 fallback', () => {
    expect(read('references/platforms.md')).toMatch(/move all inline comments into `body`/i);
  });

  it('does not run placeholder test scripts', () => {
    expect(read('references/checks.md')).toMatch(/no test specified/);
  });

  it('defines where the tests role puts its checks result', () => {
    expect(read('references/report-format.md')).toMatch(/```checks/);
  });

  it('never calls an MR ready to merge when its checks did not run', () => {
    expect(read('references/report-format.md')).toMatch(/checks not verified/i);
  });
});

describe('mr-review review context', () => {
  it('reads project docs from the target branch, not the MR worktree', () => {
    expect(read('SKILL.md')).toMatch(/git show <remote>\/<target>:<path>/);
    expect(read('SKILL.md')).toMatch(/never from the worktree/i);
    expect(read('references/modes.md')).toMatch(/Project context/);
    expect(read('references/modes.md')).toMatch(/git show <remote>\/<target>:<path>/);
  });

  it('checks every finding against code outside the diff before reporting it', () => {
    expect(read('references/report-format.md')).toMatch(/\*\*Before you report\*\*/);
    expect(read('references/report-format.md')).toMatch(/do not return it/i);
  });

  it('requires evidence and carries it through merging and the vote', () => {
    const format = read('references/report-format.md');
    expect(format).toMatch(/"evidence":/);
    expect(format).toMatch(/empty\s+`evidence` means there is no finding/i);
    const modes = read('references/modes.md');
    expect(modes).toMatch(/drop every finding with an empty `evidence`/i);
    expect(modes).toMatch(/`evidence` joined with `; `/);
    expect(modes).toMatch(/each finding with its\s+`evidence`/i);
  });
});

describe('mr-review severity calibration', () => {
  it('sets the colour by impact and lets proof only lower it', () => {
    const format = read('references/report-format.md');
    expect(format).toMatch(/Impact sets the colour/);
    expect(format).toMatch(/Proof can only lower it/);
    expect(format).toMatch(/not demonstrated/);
    expect(format).toMatch(/Proof never\s+raises a finding above its impact/);
  });

  it('keeps reproducible cosmetics minor and edge cases without tests major', () => {
    expect(read('references/report-format.md')).toMatch(/still `minor`/);
    expect(read('references/report-format.md')).toMatch(/edge case of the changed logic without a\s+test is `major`, never `minor`/);
    expect(read('references/roles/correctness.md')).toMatch(/Not a blocker even when it reproduces/);
    expect(read('references/roles/tests.md')).toMatch(/without a test → `major`, not `minor`/);
  });

  it('caps unreachable impact at major', () => {
    expect(read('references/report-format.md')).toMatch(/no caller yet/);
    expect(read('SKILL.md')).toMatch(/no caller yet/);
  });

  it('never passes Context globs to diff.sh', () => {
    expect(read('SKILL.md')).toMatch(/`Context` globs are never passed to `diff.sh`/);
  });

  it('gives blocker examples in the correctness and security roles', () => {
    expect(read('references/roles/correctness.md')).toMatch(/Blocker examples/);
    expect(read('references/roles/security.md')).toMatch(/another user's credentials/);
  });
});

describe('mr-review key journeys and domains', () => {
  it('passes Journeys and Domains to diff.sh and raises the mode by them', () => {
    expect(read('SKILL.md')).toMatch(/--journey '<name>=<glob>'\]…/);
    const modes = read('references/modes.md');
    expect(modes).toMatch(/Two or more `journey:`\s+lines, or two or more `domain:` lines → propose `ultra`/);
    expect(modes).toMatch(/deepest mode any signal asks for/);
    expect(modes).toMatch(/`journey:`, `domain:` and `manifest:` lines/);
    expect(read('references/report-format.md')).toMatch(/key journeys \(<names>\) and domains \(<names>\) — `<mode>` is recommended/);
    expect(read('references/modes.md')).not.toMatch(/journeys, contexts/);
    expect(read('references/review-md-template.md')).toMatch(/## Journeys[\s\S]*## Domains/);
  });
});

describe('mr-review intent role', () => {
  it('checks the MR against its task and spec, paired with correctness', () => {
    expect(read('references/roles/intent.md')).toMatch(/does what it was asked to do/);
    expect(read('references/roles/intent.md')).toMatch(/Quote the requirement and point at the code/);
    expect(read('references/modes.md')).toMatch(/correctness \+ intent \(both role files\)/);
    expect(read('references/modes.md')).toMatch(/all six role checklists/);
    expect(read('references/roles/intent.md')).toMatch(/no caller yet/);
    expect(read('references/roles/intent.md')).toMatch(/the bug is correctness's finding/);
    expect(read('references/roles/correctness.md')).not.toMatch(/MR description vs the code/);
  });
});

describe('mr-review risk and stack', () => {
  it('raises the mode for risky paths, in the rules and in the report layout', () => {
    expect(read('references/modes.md')).toMatch(/`risky:`[\s\S]*at least `hard`/);
    expect(read('references/report-format.md')).toMatch(/touches risky paths/);
    expect(read('SKILL.md')).toMatch(/--risky '<glob>'\]…[^\n]*"\$\(git merge-base/);
  });

  it('checks library API findings against the docs of the version in use', () => {
    const format = read('references/report-format.md');
    expect(format).toMatch(/not verified against docs/);
    expect(format).toMatch(/version on your own machine is not the project's/i);
    expect(read('references/modes.md')).toMatch(/`manifest:`/);
  });
});
