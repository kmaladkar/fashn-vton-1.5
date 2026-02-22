#!/usr/bin/env bash
# Call the try-on API with example images and save the result locally.
# Run from repo root. Requires the Docker API to be up (docker compose up).

set -e
cd "$(dirname "$0")/.."
API_URL="${FASHN_API_URL:-http://localhost:8080}"
OUTPUT="${1:-result.png}"

echo "Calling $API_URL/try-on (person=examples/data/model.webp, garment=examples/data/garment.webp, category=tops)"
echo "Output: $OUTPUT"
curl -sS -X POST "$API_URL/try-on" \
  -F "person_image=@examples/data/model.webp" \
  -F "garment_image=@examples/data/garment.webp" \
  -F "category=tops" \
  -o "$OUTPUT" \
  -w "\nHTTP %{http_code}, saved %{size_download} bytes to $OUTPUT\n" \
  --max-time 300

if [ -s "$OUTPUT" ]; then
  echo "Done. Open $OUTPUT to view the result."
else
  echo "No data received. Is the container up? Try: docker compose logs -f"
  exit 1
fi
