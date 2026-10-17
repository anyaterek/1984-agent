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
# Then main gets docs/pricing.md (rules R-1, R-2) and a REVIEW.md pointing at
# docs/, and these branches start from that commit:
#   ci-risky       a 5-line .gitlab-ci.yml, nothing else
#   explained      floorCents() floors on purpose, as docs/pricing.md R-1 says
#   edge-gaps      validateQuantity() accepts 0 although R-2 says 1..99, the
#                  upper bound 99 is not tested, and a one-letter parameter
#   api-usage      parseLink() uses the legacy url.parse(); engines node >=22
# Then main gets docs/tasks/T-7.md (every scenario now sees it as project
# context through REVIEW.md → Context: docs/**), and from there:
#   off-spec       cartTotal() for T-7: clean code and green tests, but no R-1
#                  flooring and an empty cart returns 0 instead of throwing
# Then REVIEW.md on main gets Journeys over src/checkout/ and src/orders/ (no
# earlier branch touches them), and from there:
#   two-journeys   one small file in each of the two journeys
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
mkdir -p docs
cat > docs/pricing.md <<'MD'
# Pricing rules

- R-1. Prices are floored to whole cents, never rounded up: `floorCents(1.239)` is `1.23`. Customers must never pay more than the shown price.
- R-2. An order quantity is an integer from 1 to 99 inclusive.
MD
cat > REVIEW.md <<'MD'
# Review rules

## Context
- `docs/**`
MD
commit "docs: pricing rules and review context"

g checkout -q -b ci-risky main
cat > .gitlab-ci.yml <<'YML'
test:
  image: node:22
  script:
    - npm test
    - npm run build
YML
commit "ci: run tests and build"

g checkout -q -b explained main
cat > src/price.js <<'JS'
// Floors to whole cents (docs/pricing.md R-1).
export function floorCents(value) {
  return Math.floor(value * 100) / 100;
}
JS
cat > test/price.test.js <<'JS'
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { floorCents } from '../src/price.js';

test('floors to whole cents', () => assert.equal(floorCents(1.239), 1.23));
JS
commit "feat: floor prices to cents"

g checkout -q -b edge-gaps main
cat > src/quantity.js <<'JS'
// Validates an order quantity.
export function validateQuantity(q) {
  if (!Number.isInteger(q) || q < 0 || q > 99) throw new RangeError('quantity must be within 1..99');
  return q;
}
JS
cat > test/quantity.test.js <<'JS'
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { validateQuantity } from '../src/quantity.js';

test('accepts 5', () => assert.equal(validateQuantity(5), 5));
test('rejects 100', () => assert.throws(() => validateQuantity(100), RangeError));
test('rejects 2.5', () => assert.throws(() => validateQuantity(2.5), RangeError));
JS
commit "feat: validate order quantity"

g checkout -q -b api-usage main
cat > package.json <<'JSON'
{
  "name": "shop-pricing",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=22"
  },
  "scripts": {
    "build": "node build.js",
    "test": "node --test"
  }
}
JSON
cat > src/link.js <<'JS'
import url from 'node:url';

// Returns the path of a product link.
export function parseLink(input) {
  return url.parse(input).pathname;
}
JS
cat > test/link.test.js <<'JS'
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseLink } from '../src/link.js';

test('returns the path', () => assert.equal(parseLink('https://shop.example/p/42?ref=x'), '/p/42'));
JS
commit "feat: parse product links"

g checkout -q main
mkdir -p docs/tasks
cat > docs/tasks/T-7.md <<'MD'
# T-7. Cart total

Add `cartTotal(items)` in `src/cart.js`.

- Returns the sum of `price * qty` over all items, floored to whole cents (docs/pricing.md R-1).
- Rejects an empty cart with `RangeError` — an order without items must not reach payment.
MD
commit "docs: task T-7 cart total"

g checkout -q -b off-spec main
cat > src/cart.js <<'JS'
// Total of a cart (T-7).
export function cartTotal(items) {
  return items.reduce((sum, item) => sum + item.price * item.qty, 0);
}
JS
cat > test/cart.test.js <<'JS'
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { cartTotal } from '../src/cart.js';

test('sums price times quantity', () => assert.equal(cartTotal([{ price: 2, qty: 3 }, { price: 5, qty: 1 }]), 11));
test('an empty cart costs nothing', () => assert.equal(cartTotal([]), 0));
JS
commit "feat: cart total (T-7)"

g checkout -q main
cat >> REVIEW.md <<'MD'

## Journeys
- checkout: `src/checkout/*`
- ordering: `src/orders/*`
MD
commit "docs: key journeys"

g checkout -q -b two-journeys main
mkdir -p src/checkout src/orders
cat > src/checkout/summary.js <<'JS'
// Line shown above the pay button.
export function checkoutSummary(total) {
  return `To pay: ${total} ₽`;
}
JS
cat > src/orders/limits.js <<'JS'
// Largest order quantity (docs/pricing.md R-2).
export const MAX_QUANTITY = 99;
JS
commit "feat: checkout summary and order limit"

g checkout -q main
cd "$root"
git clone -q --bare seed origin.git
git clone -q origin.git repo
rm -rf seed
cd repo
for b in cosmetic logic-bug huge env-dependent ci-risky explained edge-gaps api-usage off-spec two-journeys; do git branch -q "$b" "origin/$b"; done
pwd
