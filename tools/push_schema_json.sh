#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
	echo "Usage: $(basename "$0") <schema-name> <source-dir> <commit-url>"
	exit 1
fi

# @param $1 - Schema name used as the output filename (e.g. "dota2")
# @param $2 - Source directory containing DumpSource2/schemas.json
# @param $3 - Commit URL included in the commit body
SCHEMA_NAME="$1"
SOURCE_DIR="$2"
COMMIT_URL="$3"

NEW_JSON="$SOURCE_DIR/DumpSource2/schemas.json"
EXISTING_JSON="$SCHEMA_NAME.json"

# strip_metadata - Strips revision, version_date, and version_time fields from schema JSON.
#   Reads from a file argument or stdin. Output is sorted and compact for consistent comparison.
strip_metadata() {
	jq --sort-keys --compact-output 'del(.revision, .version_date, .version_time)' "$@"
}

if [[ -f "$EXISTING_JSON" ]]; then
	OLD_STRIPPED=$(strip_metadata "$EXISTING_JSON")
	NEW_STRIPPED=$(strip_metadata "$NEW_JSON")

	if [[ "$NEW_STRIPPED" == "$OLD_STRIPPED" ]]; then
		echo "No schema changes for $SCHEMA_NAME, skipping"
		exit 0
	fi
fi

REVISION=$(jq --raw-output '.revision' "$NEW_JSON")

mv "$NEW_JSON" "$SCHEMA_NAME.json"
git add "$SCHEMA_NAME.json"
git commit -m "Update $SCHEMA_NAME schema (revision $REVISION)" -m "$COMMIT_URL"

# Retry push in case another game updated the repo concurrently
for i in 1 2 3; do
	if git push; then
		exit 0
	fi
	echo "Push failed (attempt $i), pulling and retrying..."
	sleep "$((i * 5))"
	git pull --rebase
done

echo "Push failed after 3 attempts"
exit 1
