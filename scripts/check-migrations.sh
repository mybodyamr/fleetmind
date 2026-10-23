#!/usr/bin/env bash
# Guards the migrations directory.
#   1. DROP TABLE / DROP COLUMN / TRUNCATE need a sibling "<migration>.review.md"
#      (review notes + backup + rollback plan).
#   2. INSERT INTO is only allowed on reference-data tables. Test or demo data
#      belongs in supabase/seed.sql, never in a migration.
# Usage: scripts/check-migrations.sh <migrations_dir>
set -u

dir="${1:-}"
if [ -z "$dir" ] || [ ! -d "$dir" ]; then
  echo "usage: check-migrations.sh <migrations_dir>" >&2
  exit 2
fi

# Tables whose rows are reference data and may be inserted by a migration.
ALLOWED_INSERT_TABLES=" roles permissions role_permissions settings "

# Lowercase SQL with comments removed, quotes removed and whitespace collapsed.
normalize() {
  perl -0777 -pe 's{/\*.*?\*/}{ }gs; s{--[^\n]*}{ }g; $_ = lc $_; s{"}{}g; s{\s+}{ }g' "$1"
}

status=0
shopt -s nullglob
for f in "$dir"/*.sql; do
  base="${f%.sql}"
  sql="$(normalize "$f")"

  if printf '%s' "$sql" | grep -Eq '(^|[^a-z_])(drop table|drop column|truncate)([^a-z_]|$)'; then
    if [ ! -f "$base.review.md" ]; then
      echo "ERROR: $(basename "$f") has a destructive statement but $(basename "$base").review.md is missing" >&2
      status=1
    fi
  fi

  while IFS= read -r target; do
    [ -z "$target" ] && continue
    table="${target##*.}"
    case "$ALLOWED_INSERT_TABLES" in
      *" $table "*) ;;
      *)
        echo "ERROR: $(basename "$f") inserts into '$table'; only reference tables are allowed in migrations (use supabase/seed.sql for dev data)" >&2
        status=1
        ;;
    esac
  done < <(printf '%s' "$sql" | grep -oE 'insert into [a-z0-9_.]+' | sed 's/^insert into //')
done

exit $status
