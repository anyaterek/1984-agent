# REVIEW.md template

Copy the block below to `REVIEW.md` in the repository root and fill it in.
Every section is optional; delete what you do not need. mr-review reads this
file on every run and passes it to all reviewers, so the whole team gets the
same review without explaining the context each time.

````markdown
# Review rules

## Stack
<!-- Languages, frameworks, key libraries. Reviewers use it to judge idioms. -->
- TypeScript (strict), React, Next.js App Router
- NestJS, Prisma, PostgreSQL

## Conventions
<!-- What a reviewer should hold the code to, beyond common sense. -->
- Conventional Commits
- No default exports
- Server code never imports from `app/(client)`

## Blockers
<!-- Extra rules that make a finding a 🔴 blocker in this project. -->
- Any Prisma migration without a matching rollback note in the MR
- Changes to `src/payments/**` without an e2e test

## Hot paths
<!-- Code where performance findings matter most. -->
- `src/search/**`

## Commands
<!-- Overrides auto-detection. Leave out what auto-detection gets right. -->
- install: `bun install --frozen-lockfile`
- build: `bun run build`
- test: `bun run test`

## Ignore
<!-- Globs never reviewed (generated code, fixtures, vendored files). -->
- `src/generated/**`
- `**/*.snap`

## Settings
- comment_language: ru
<!-- Needed only for self-hosted hosts that mr-review cannot recognise. -->
- platform: gitlab
````
