import { spawnSync } from 'node:child_process';
import { join, resolve } from 'node:path';

export const SCRIPTS = resolve(import.meta.dirname, '../../skills/mr-review/scripts');

export interface RunResult {
  code: number;
  stdout: string;
  stderr: string;
}

export interface RunOptions {
  cwd?: string;
  env?: Record<string, string>;
}

/** Runs a skill script the way an agent would: via `sh`, so the executable bit is not required. */
export function run(script: string, args: string[], opts: RunOptions = {}): RunResult {
  const result = spawnSync('sh', [join(SCRIPTS, script), ...args], {
    cwd: opts.cwd,
    env: { ...process.env, ...opts.env },
    encoding: 'utf8',
  });
  return {
    code: result.status ?? -1,
    stdout: result.stdout.trim(),
    stderr: result.stderr.trim(),
  };
}
