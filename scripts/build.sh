#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$ROOT"

PROJ_NAME=$(grep -E '^name:[[:space:]]' project.yml | head -1 | awk '{print $2}')
if [[ -z "${PROJ_NAME}" ]]; then
  echo "error: could not read name from project.yml" >&2
  exit 1
fi

MODE=$(echo "${1:-debug}" | tr '[:upper:]' '[:lower:]')
xcodegen generate

if [[ "$MODE" == "release" ]]; then
  CONFIG=Release
  DERIVED="${ROOT}/build/ReleaseDerivedData"
  rm -rf "${ROOT}/dist" "$DERIVED"
  mkdir -p "${ROOT}/dist"
else
  CONFIG=Debug
  DERIVED="${ROOT}/build/DerivedData"
  rm -rf "$DERIVED"
fi

xcodebuild -project "${PROJ_NAME}.xcodeproj" \
  -scheme "${PROJ_NAME}" \
  -configuration "${CONFIG}" \
  -derivedDataPath "${DERIVED}" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  build

if [[ "$MODE" == "release" ]]; then
  ditto "${DERIVED}/Build/Products/Release/${PROJ_NAME}.app" "${ROOT}/dist/${PROJ_NAME}.app"
  echo "Release app: ${ROOT}/dist/${PROJ_NAME}.app"
else
  echo "Debug app: ${DERIVED}/Build/Products/Debug/${PROJ_NAME}.app"
fi
