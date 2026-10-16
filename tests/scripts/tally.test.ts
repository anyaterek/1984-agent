import { describe, expect, it } from 'vitest';
import { run } from '../helpers/run.js';

const tally = (...votes: string[]) => run('tally.sh', votes);

describe('tally.sh', () => {
  it('reports a unanimous vote', () => {
    expect(tally('major', 'major', 'major', 'major', 'major').stdout)
      .toBe('major unanimous blocker=0 major=5 minor=0 none=0');
  });

  it('takes the majority and marks a split vote as disputed', () => {
    expect(tally('blocker', 'blocker', 'blocker', 'minor', 'none').stdout)
      .toBe('blocker disputed blocker=3 major=0 minor=1 none=1');
  });

  it('resolves a 2/2/1 split by median instead of a tie', () => {
    expect(tally('blocker', 'blocker', 'minor', 'minor', 'none').stdout)
      .toBe('minor disputed blocker=2 major=0 minor=2 none=1');
  });

  it('does not depend on vote order', () => {
    expect(tally('none', 'minor', 'blocker', 'minor', 'blocker').stdout)
      .toBe(tally('blocker', 'blocker', 'minor', 'minor', 'none').stdout);
  });

  it('rejects a finding when the majority votes none', () => {
    expect(tally('none', 'none', 'none', 'major', 'blocker').stdout).toMatch(/^none disputed /);
  });

  it('fails on an unknown severity token', () => {
    const r = tally('major', 'critical');
    expect(r.code).toBe(2);
    expect(r.stderr).toContain('critical');
  });

  it('fails when no votes are given', () => {
    expect(tally().code).toBe(2);
  });
});
