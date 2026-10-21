#!/usr/bin/env sh
# Reports which Docuveil dev tools are present on this Linux/macOS machine.
for t in git gh flutter dart python3 node docker tesseract psql java; do
  if command -v "$t" >/dev/null 2>&1; then printf '%-10s %s\n' "$t" "$(command -v "$t")"; else printf '%-10s MISSING\n' "$t"; fi
done
df -h . | tail -1
