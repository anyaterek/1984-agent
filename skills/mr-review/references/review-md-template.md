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

## Context
<!-- Docs every reviewer checks a finding against. Read from the target branch. -->
- `docs/specs/**`
- `docs/DECISIONS.md`

## Risky paths
<!-- Paths that always get at least `hard`. Built in already: CI, Dockerfile and
     compose, deploy scripts, migrations, `auth/`, REVIEW.md, AGENTS.md, CLAUDE.md. -->
- `src/payments/**`

## Journeys
<!-- Critical user journeys: what users come to do, and where it lives in code.
     Keep globs narrow. One journey touched → at least `hard`; two or more → `ultra`. -->
- checkout: `src/checkout/**`, `src/payments/**`
- sign-in: `src/auth/**`, `src/session/**`

## Domains
<!-- Domains: bounded contexts of the domain model (DDD) — not the same as
     `Context` above. An MR across two or more → `ultra`. -->
- catalog: `src/catalog/**`
- orders: `src/orders/**`

## Docs
<!-- Team guides and docs of key libraries; reviewers check API findings here first. -->
- Fastify: https://fastify.dev/docs/latest/
- Our API guide: `docs/api-guide.md`

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
