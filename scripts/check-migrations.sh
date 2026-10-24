#!/usr/bin/env bash
# A best-effort tripwire for the migrations directory. It stops accidents; it is not a
# security boundary (a determined author can always hide a statement), so human review of
# every migration still applies.
#   1. DROP TABLE / DROP COLUMN / DROP SCHEMA / DELETE FROM / TRUNCATE need a sibling
#      "<migration>.review.md" that is non-empty and mentions both a backup and a rollback.
#   2. INSERT INTO is only allowed on reference-data tables in the public schema.
#      Test or demo data belongs in supabase/seed.sql, never in a migration.
# Bodies of CREATE FUNCTION/PROCEDURE are code, not statements run by the migration, so
# they are skipped. DO blocks run immediately and are checked. Calling a function that
# writes data cannot be detected here.
# Usage: scripts/check-migrations.sh <migrations_dir>
# Exit codes: 0 ok, 1 findings, 2 the guard itself could not run (it fails closed).
set -u
set -o pipefail

dir="${1:-}"
if [ -z "$dir" ] || [ ! -d "$dir" ]; then
  echo "usage: check-migrations.sh <migrations_dir>" >&2
  exit 2
fi
if ! command -v perl >/dev/null 2>&1; then
  echo "ERROR: perl is required by the migration guard and was not found" >&2
  exit 2
fi

# Tables whose rows are reference data and may be inserted by a migration (public schema).
ALLOWED_INSERT_TABLES=" roles permissions role_permissions settings "

# One left-to-right pass so a quote inside a comment, or "--" inside a string, cannot confuse
# the next step: string literals become '', comments become a space. Then lowercase, drop
# double quotes and collapse whitespace.
normalize() {
  perl -0777 -pe 's{(\x27(?:[^\x27]|\x27\x27)*\x27)|(--[^\n]*)|(/\*.*?\*/)}{defined $1 ? "\x27\x27" : " "}gse; $_ = lc $_; s{"}{}g; s{\s+}{ }g' "$1"
}

strip_function_bodies() {
  perl -0777 -pe 's{create\s+(?:or\s+replace\s+)?(?:function|procedure)\b.*?(\$[a-z0-9_]*\$).*?\1}{create function stripped}gs'
}

# GRANT/REVOKE statements list privileges such as TRUNCATE; they are not destructive.
strip_privilege_statements() {
  perl -0777 -pe 's{\b(?:grant|revoke)\b[^;]*;}{ }g'
}

status=0
shopt -s nullglob
for f in "$dir"/*.sql; do
  base="${f%.sql}"
  if ! sql="$(normalize "$f" | strip_function_bodies | strip_privilege_statements)"; then
    echo "ERROR: could not analyse $(basename "$f")" >&2
    exit 2
  fi

  destructive='(^|[^a-z_])(drop table|drop column|drop schema|delete from)([^a-z_]|$)|(^|;|\$\$|[^a-z_](begin|then|else|loop)) ?truncate([^a-z_]|$)'
  if printf '%s' "$sql" | grep -Eq "$destructive"; then
    review="$base.review.md"
    if [ ! -s "$review" ] || ! grep -qi 'backup' "$review" || ! grep -qi 'rollback' "$review"; then
      echo "ERROR: $(basename "$f") has a destructive statement but $(basename "$base").review.md is missing, empty, or does not cover both a backup and a rollback" >&2
      status=1
    fi
  fi

  while IFS= read -r target; do
    [ -z "$target" ] && continue
    table="${target##*.}"
    schema="public"
    case "$target" in *.*) schema="${target%.*}" ;; esac
    if [ "$schema" != "public" ] || [[ "$ALLOWED_INSERT_TABLES" != *" $table "* ]]; then
      echo "ERROR: $(basename "$f") inserts into '$target'; only public reference tables are allowed in migrations (use supabase/seed.sql for dev data)" >&2
      status=1
    fi
  done < <(printf '%s' "$sql" | grep -oE 'insert into [a-z0-9_.]+' | sed 's/^insert into //')
done

exit $status
