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
