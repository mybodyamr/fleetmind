#!/usr/bin/env bash
# Tests for scripts/check-migrations.sh. Run: bash scripts/check-migrations.test.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
check="$here/check-migrations.sh"
fail=0

if [ ! -f "$check" ]; then
  echo "FAIL: check-migrations.sh is missing"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
m="$tmp/m"

fresh() { rm -rf "$m"; mkdir -p "$m"; }

expect() { # name, wanted exit code
  local name="$1" want="$2" got
  bash "$check" "$m" >/dev/null 2>&1
  got=$?
  if [ "$got" -ne "$want" ]; then
    echo "FAIL: $name (wanted exit $want, got $got)"
    fail=1
  else
    echo "ok: $name"
  fi
}

fresh; echo 'select 1;' > "$m/0001_ok.sql"
expect "plain migration passes" 0

fresh; echo 'alter table t drop column c;' > "$m/0001_x.sql"
expect "drop column without review fails" 1
echo 'backup taken, rollback plan written' > "$m/0001_x.review.md"
expect "drop column with review passes" 0

fresh; echo 'DROP TABLE IF EXISTS t;' > "$m/0001_x.sql"
expect "drop table without review fails" 1

fresh; echo 'truncate t;' > "$m/0001_x.sql"
expect "truncate without review fails" 1

fresh; echo '-- drop table old_thing;' > "$m/0001_x.sql"
expect "destructive words inside comments are ignored" 0

fresh; echo "insert into vehicles (id) values (1);" > "$m/0001_x.sql"
expect "insert into a non-reference table fails" 1

fresh; printf "insert into\n  public.vehicles (id) values (1);\n" > "$m/0001_x.sql"
expect "multi-line insert into a non-reference table fails" 1

fresh; echo "insert into public.roles (name) values ('driver');" > "$m/0001_x.sql"
expect "insert into a reference table passes" 0

exit $fail
