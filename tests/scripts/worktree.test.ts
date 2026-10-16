import { existsSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { cleanupTempDirs, git, makeRepo, tempDir } from '../helpers/git-fixture.js';
import { run } from '../helpers/run.js';

const created: { dir: string; path: string }[] = [];
const create = (dir: string, spec: string) => {
  const r = run('worktree.sh', ['create', spec], { cwd: dir });
  if (r.code === 0) created.push({ dir, path: r.stdout });
  return r;
};
const remove = (dir: string, path: string) => run('worktree.sh', ['remove', path], { cwd: dir });
const worktreePaths = (dir: string) =>
  git(dir, 'worktree', 'list', '--porcelain')
    .split('\n')
    .filter((line) => line.startsWith('worktree '))
    .map((line) => line.slice('worktree '.length));

afterEach(() => {
  for (const { dir, path } of created.splice(0)) remove(dir, path);
  cleanupTempDirs();
});

describe('worktree.sh', () => {
  it('checks out a GitHub PR (pr:<n>) into a temporary worktree', () => {
    const { dir } = makeRepo();
    const r = create(dir, 'pr:7');
    expect(r.code).toBe(0);
    expect(readFileSync(join(r.stdout, 'feature.txt'), 'utf8')).toBe('feature\n');
  });

  it('checks out a GitLab MR (mr:<n>) into a temporary worktree', () => {
    const { dir } = makeRepo();
    const r = create(dir, 'mr:7');
    expect(r.code).toBe(0);
    expect(existsSync(join(r.stdout, 'feature.txt'))).toBe(true);
  });

  it('checks out a remote branch (ref:origin/main) for the baseline run', () => {
    const { dir } = makeRepo();
    const r = create(dir, 'ref:origin/main');
    expect(r.code).toBe(0);
    expect(existsSync(join(r.stdout, 'README.md'))).toBe(true);
    expect(existsSync(join(r.stdout, 'feature.txt'))).toBe(false);
  });

  it('places the worktree outside the repository', () => {
    const { dir } = makeRepo();
    const r = create(dir, 'pr:7');
    expect(r.stdout.startsWith(dir)).toBe(false);
    expect(r.stdout).toMatch(/mr-review-clone-[0-9]+-pr-7$/);
  });

  it('leaves the user working tree and branch untouched', () => {
    const { dir } = makeRepo();
    const before = [git(dir, 'status', '--porcelain'), git(dir, 'branch', '--show-current')];
    create(dir, 'pr:7');
    expect([git(dir, 'status', '--porcelain'), git(dir, 'branch', '--show-current')]).toEqual(before);
  });

  it('replaces a stale worktree left by an interrupted run', () => {
    const { dir } = makeRepo();
    const first = create(dir, 'pr:7');
    const second = create(dir, 'pr:7');
    expect(second.code).toBe(0);
    expect(second.stdout).toBe(first.stdout);
    expect(worktreePaths(dir).filter((p) => p.endsWith('pr-7'))).toHaveLength(1);
  });

  it('removes the worktree and its fetched ref, idempotently', () => {
    const { dir } = makeRepo();
    const path = create(dir, 'pr:7').stdout;
    expect(remove(dir, path).code).toBe(0);
    expect(remove(dir, path).code).toBe(0);
    expect(existsSync(path)).toBe(false);
    expect(worktreePaths(dir).some((p) => p.endsWith('pr-7'))).toBe(false);
    expect(git(dir, 'for-each-ref', 'refs/mr-review')).toBe('');
  });

  it('refuses to remove a path it did not create', () => {
    const { dir } = makeRepo();
    const r = remove(dir, dir);
    expect(r.code).toBe(2);
    expect(existsSync(dir)).toBe(true);
  });

  it('refuses to remove a main repository named mr-review-* inside TMPDIR', () => {
    const { dir } = makeRepo();
    const victim = join(tmpdir(), `mr-review-demo-${Date.now()}`);
    git(tmpdir(), 'init', '-q', victim);
    try {
      const r = remove(dir, victim);
      expect(r.code).toBe(2);
      expect(existsSync(join(victim, '.git'))).toBe(true);
    } finally {
      rmSync(victim, { recursive: true, force: true });
    }
  });

  it('refuses to remove an mr-review-* folder outside TMPDIR', () => {
    const { dir } = makeRepo();
    const outside = join(tempDir(), 'mr-review-notes');
    mkdirSync(outside);
    const r = run('worktree.sh', ['remove', outside], { cwd: dir, env: { TMPDIR: tempDir() } });
    expect(r.code).toBe(2);
    expect(existsSync(outside)).toBe(true);
  });

  it('rejects a non-numeric PR number', () => {
    const { dir } = makeRepo();
    expect(create(dir, 'pr:7abc').code).toBe(2);
  });

  it('fails with a clear message for a PR that does not exist', () => {
    const { dir } = makeRepo();
    const r = create(dir, 'pr:999');
    expect(r.code).toBe(1);
    expect(r.stderr).toContain('pr:999');
  });

  it('rejects an unknown spec', () => {
    const { dir } = makeRepo();
    expect(create(dir, 'branch:main').code).toBe(2);
  });
});
