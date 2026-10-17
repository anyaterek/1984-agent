import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const SKILL_DIR = resolve(import.meta.dirname, '../skills/mr-review');
const ROLE_FILES = ['architecture.md', 'correctness.md', 'intent.md', 'performance.md', 'security.md', 'tests.md'];

function filesUnder(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? filesUnder(path) : [path];
  });
}

/** Relative link targets of a markdown file, resolved to absolute paths (anchors and URLs skipped). */
function markdownLinks(file: string): string[] {
  const text = readFileSync(file, 'utf8');
  return [...text.matchAll(/\]\(([^)\s]+)\)/g)]
    .map((m) => m[1].split('#')[0])
    .filter((target) => target !== '' && !/^[a-z]+:/i.test(target))
    .map((target) => resolve(dirname(file), target));
}

const markdownFiles = () => filesUnder(SKILL_DIR).filter((f) => f.endsWith('.md'));

describe('mr-review skill structure', () => {
  it('has every reviewer role file', () => {
    expect(readdirSync(join(SKILL_DIR, 'references/roles')).sort()).toEqual(ROLE_FILES);
  });

  it('has no broken relative links', () => {
    const broken = markdownFiles().flatMap((file) =>
      markdownLinks(file)
        .filter((target) => !existsSync(target))
        .map((target) => `${relative(SKILL_DIR, file)} -> ${relative(SKILL_DIR, target)}`),
    );
    expect(broken).toEqual([]);
  });

  it('has SKILL.md frontmatter that triggers on MR/PR review requests', () => {
    const text = readFileSync(join(SKILL_DIR, 'SKILL.md'), 'utf8');
    const frontmatter = text.match(/^---\n([\s\S]*?)\n---\n/)?.[1] ?? '';
    expect(frontmatter).toMatch(/^name: mr-review$/m);
    const description = frontmatter.match(/^description: (.*)$/m)?.[1] ?? '';
    expect(description.startsWith('Use when')).toBe(true);
    expect(description.length).toBeLessThanOrEqual(1024);
    for (const word of ['merge request', 'pull request', 'standard', 'hard', 'ultra']) {
      expect(description.toLowerCase()).toContain(word);
    }
  });

  it('reaches every reference and script from SKILL.md through links', () => {
    const reachable = new Set<string>();
    const queue = [join(SKILL_DIR, 'SKILL.md')];
    while (queue.length > 0) {
      const file = queue.pop()!;
      if (reachable.has(file) || !existsSync(file)) continue;
      reachable.add(file);
      if (file.endsWith('.md')) queue.push(...markdownLinks(file));
    }
    const unreachable = filesUnder(SKILL_DIR)
      .filter((f) => f !== join(SKILL_DIR, 'SKILL.md') && !reachable.has(f))
      .map((f) => relative(SKILL_DIR, f));
    expect(unreachable).toEqual([]);
  });

  it('links every role file from another skill file', () => {
    const linked = new Set(markdownFiles().flatMap(markdownLinks));
    const orphans = ROLE_FILES.filter((f) => !linked.has(join(SKILL_DIR, 'references/roles', f)));
    expect(orphans).toEqual([]);
  });
});
