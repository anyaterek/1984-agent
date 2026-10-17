#!/bin/sh
# Prepares one eval scenario on top of make-fixture.sh.
# Usage: sh evals/setup-scenario.sh <E1..E14> <dir>   — prints the repo path.
set -eu
[ $# -eq 2 ] || { echo "usage: setup-scenario.sh <scenario> <dir>" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
repo=$(sh "$here/make-fixture.sh" "$2")
root=$(cd "$2" && pwd)
cd "$repo"
g() { git -c user.name=Fixture -c user.email=fixture@example.com "$@"; }

case "$1" in
  E1) g checkout -q cosmetic ;;
  E2|E3|E4) g checkout -q logic-bug ;;
  E5)
    g checkout -q logic-bug
    node -e "const f='package.json',p=JSON.parse(require('fs').readFileSync(f));delete p.scripts;require('fs').writeFileSync(f,JSON.stringify(p,null,2)+'\n')"
    g commit -qam "chore: drop npm scripts"
    ;;
  E6) g checkout -q huge ;;
  E7)
    g checkout -q logic-bug
    git remote set-url origin git@github.com:acme-fixture/shop-pricing.git
    mkdir -p "$root/fakebin"
    cat > "$root/fakebin/gh" <<'GH'
#!/bin/sh
echo "You are not logged into any GitHub hosts. To log in, run: gh auth login" >&2
exit 1
GH
    chmod +x "$root/fakebin/gh"
    ;;
  E8) g checkout -q env-dependent ;;
  E9) g checkout -q ci-risky ;;
  E10) g checkout -q explained ;;
  E11) g checkout -q edge-gaps ;;
  E12) g checkout -q api-usage ;;
  E13) g checkout -q off-spec ;;
  E14) g checkout -q two-journeys ;;
  *) echo "unknown scenario $1" >&2; exit 2 ;;
esac
pwd
