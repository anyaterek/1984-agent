import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const createdDirs: string[] = [];

/** A fresh temp directory that `cleanupTempDirs` deletes. */
export function tempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), 'mr-review-test-'));
  createdDirs.push(dir);
  return dir;
}

export function cleanupTempDirs(): void {
  for (const dir of createdDirs.splice(0)) rmSync(dir, { recursive: true, force: true });
}

export function git(cwd: string, ...args: string[]): string {
  return execFileSync('git', ['-c', 'user.name=Test', '-c', 'user.email=test@example.com', ...args], {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  }).trim();
}

export interface FixtureRepo {
  /** Clone the skill runs in; `origin` points at `remote`. */
  dir: string;
  /** Bare repository acting as GitHub/GitLab. */
  remote: string;
}

/**
 * A bare "remote" with `main`, a `feature` branch adding feature.txt, and the
 * same commit published as `refs/pull/7/head` (GitHub) and
 * `refs/merge-requests/7/head` (GitLab), plus a clone of it.
 */
export function makeRepo(): FixtureRepo {
  const root = tempDir();
  const seed = join(root, 'seed');
  const remote = join(root, 'remote.git');
  const dir = join(root, 'clone');

  git(root, 'init', '-q', '-b', 'main', seed);
  writeFileSync(join(seed, 'README.md'), 'fixture\n');
  git(seed, 'add', '.');
  git(seed, 'commit', '-q', '-m', 'init');
  git(seed, 'checkout', '-q', '-b', 'feature');
  writeFileSync(join(seed, 'feature.txt'), 'feature\n');
  git(seed, 'add', '.');
  git(seed, 'commit', '-q', '-m', 'feature');

  git(root, 'clone', '-q', '--bare', seed, remote);
  const featureSha = git(remote, 'rev-parse', 'feature');
  git(remote, 'update-ref', 'refs/pull/7/head', featureSha);
  git(remote, 'update-ref', 'refs/merge-requests/7/head', featureSha);

  git(root, 'clone', '-q', remote, dir);
  return { dir, remote };
}
