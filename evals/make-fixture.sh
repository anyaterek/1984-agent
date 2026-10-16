#!/bin/sh
# Builds the eval repository for mr-review: a zero-dependency Node project with
# a bare "origin" and branches carrying planted problems.
#
# Usage: sh evals/make-fixture.sh <dir>
# Creates <dir>/origin.git and <dir>/repo (a clone on main); prints the clone path.
#
# Branches:
#   main           applyDiscount + tests; test/legacy.test.js already fails here
#   cosmetic       README and comment wording only
#   logic-bug      100% discount now throws (breaks a test), roundPrice() without
#                  tests, a badly named variable
#   huge           logic-bug + 5000-line package-lock.json + dist/bundle.js
#   env-dependent  a test that needs PostgreSQL (DATABASE_URL)
set -eu

[ $# -eq 1 ] || { echo "usage: make-fixture.sh <dir>" >&2; exit 2; }
mkdir -p "$1"
root=$(cd "$1" && pwd)
rm -rf "$root/origin.git" "$root/repo" "$root/seed"
mkdir -p "$root/seed"
cd "$root/seed"

g() { git -c user.name=Fixture -c user.email=fixture@example.com "$@"; }
commit() { g add -A && g commit -q -m "$1"; }

g init -q -b main
mkdir -p src test
cat > package.json <<'JSON'
{
  "name": "shop-pricing",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "node build.js",
    "test": "node --test"
  }
}
JSON
cat > build.js <<'JS'
// "Build" = make sure every module loads.
import { readdirSync } from 'node:fs';
for (const file of readdirSync('src')) await import(`./src/${file}`);
console.log('build ok');
JS
cat > README.md <<'MD'
# shop-pricing

Price helpers for the shop.
MD
cat > src/discount.js <<'JS'
// Applies a percentage discount to a price.
export function applyDiscount(price, percent) {
  if (percent < 0 || percent > 100) throw new RangeError('percent must be within 0..100');
  return price - (price * percent) / 100;
}
JS
cat > src/legacy.js <<'JS'
export function legacyFormat(amount) {
  return `${amount} ₽`;
}
JS
cat > test/discount.test.js <<'JS'
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { applyDiscount } from '../src/discount.js';

test('10% off 200 is 180', () => assert.equal(applyDiscount(200, 10), 180));
test('100% discount makes the price zero', () => assert.equal(applyDiscount(50, 100), 0));
test('negative percent is rejected', () => assert.throws(() => applyDiscount(50, -1), RangeError));
JS
cat > test/legacy.test.js <<'JS'
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { legacyFormat } from '../src/legacy.js';

// Known broken on main: the format lost its decimals long ago.
test('legacy format keeps two decimals', () => assert.equal(legacyFormat(5), '5.00 ₽'));
JS
commit "init pricing"

g checkout -q -b cosmetic main
cat > README.md <<'MD'
# shop-pricing

Small price helpers used by the shop checkout.
MD
sed 's#^// Applies a percentage discount to a price.#// Returns the price after a percentage discount.#' src/discount.js > src/discount.js.new
mv src/discount.js.new src/discount.js
commit "docs: polish wording"

g checkout -q -b logic-bug main
cat > src/discount.js <<'JS'
// Applies a percentage discount to a price.
export function applyDiscount(price, percent) {
  if (percent < 0 || percent >= 100) throw new RangeError('percent must be within 0..100');
  const x2 = (price * percent) / 100;
  return price - x2;
}

export function roundPrice(value) {
  return Math.round(value * 100) / 100;
}
JS
commit "feat: add price rounding"

g checkout -q -b huge logic-bug
mkdir -p dist
{
  echo '{'
  echo '  "name": "shop-pricing",'
  echo '  "lockfileVersion": 3,'
  echo '  "packages": {'
  i=1
  while [ $i -le 4990 ]; do
    echo "    \"node_modules/pkg-$i\": { \"version\": \"1.0.$i\" },"
    i=$((i + 1))
  done
  echo '    "": { "name": "shop-pricing" }'
  echo '  }'
  echo '}'
} > package-lock.json
i=1
while [ $i -le 800 ]; do
  echo "var a$i=function(){return $i};"
  i=$((i + 1))
done > dist/bundle.js
commit "chore: commit lockfile and bundle"

g checkout -q -b env-dependent main
cat > test/db.test.js <<'JS'
import assert from 'node:assert/strict';
import { test } from 'node:test';

test('prices table is reachable', () => {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is not set: start PostgreSQL and export DATABASE_URL');
  assert.match(url, /^postgres/);
});
JS
commit "test: check database connectivity"

g checkout -q main
cd "$root"
git clone -q --bare seed origin.git
git clone -q origin.git repo
rm -rf seed
cd repo
for b in cosmetic logic-bug huge env-dependent; do git branch -q "$b" "origin/$b"; done
pwd
