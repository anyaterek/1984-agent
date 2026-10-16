import { execFileSync } from 'node:child_process';
import { afterEach, describe, expect, it } from 'vitest';
import { cleanupTempDirs, tempDir } from '../helpers/git-fixture.js';
import { run } from '../helpers/run.js';

afterEach(cleanupTempDirs);

describe('detect-platform.sh', () => {
  it.each([
    ['git@github.com:acme/app.git', 'github'],
    ['https://github.com/acme/app', 'github'],
    ['git@gitlab.com:acme/app.git', 'gitlab'],
    ['ssh://git@gitlab.acme.io:2222/team/sub/app.git', 'gitlab'],
    ['https://GitHub.Com/acme/app.git', 'github'],
    ['https://git.acme.io/team/app.git', 'unknown'],
    ['https://git.acme.io/github-mirror/app.git', 'unknown'],
    ['', 'unknown'],
  ])('%s -> %s', (url, expected) => {
    const r = run('detect-platform.sh', [url]);
    expect(r.code).toBe(0);
    expect(r.stdout).toBe(expected);
  });

  it('reads the origin remote when no argument is given', () => {
    const dir = tempDir();
    execFileSync('git', ['init', '-q'], { cwd: dir });
    execFileSync('git', ['remote', 'add', 'origin', 'git@github.com:a/b.git'], { cwd: dir });
    expect(run('detect-platform.sh', [], { cwd: dir }).stdout).toBe('github');
  });

  it('honours MR_REVIEW_REMOTE', () => {
    const dir = tempDir();
    execFileSync('git', ['init', '-q'], { cwd: dir });
    execFileSync('git', ['remote', 'add', 'origin', 'git@github.com:a/b.git'], { cwd: dir });
    execFileSync('git', ['remote', 'add', 'upstream', 'git@gitlab.com:a/b.git'], { cwd: dir });
    const r = run('detect-platform.sh', [], { cwd: dir, env: { MR_REVIEW_REMOTE: 'upstream' } });
    expect(r.stdout).toBe('gitlab');
  });

  it('returns unknown outside a git repo', () => {
    const r = run('detect-platform.sh', [], { cwd: tempDir() });
    expect(r.code).toBe(0);
    expect(r.stdout).toBe('unknown');
  });
});
