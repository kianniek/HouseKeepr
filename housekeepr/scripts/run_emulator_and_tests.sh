#!/usr/bin/env bash
set -euo pipefail

# Start the Firebase emulator and run Flutter integration/unit tests that require Firestore.
# Requires: firebase-tools installed and logged in, or FIREBASE_CLI_TOKEN set for CI.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Starting Firestore emulator..."
# Start emulator in background and redirect logs to a file
firebase emulators:start --only firestore --project=demo-project > /tmp/firebase-emulator.log 2>&1 &
EMULATOR_PID=$!

# Wait for the emulator to be ready
echo "Waiting for Firestore emulator to be ready..."
RETRY=0
MAX_RETRIES=30
until grep -q "All emulators ready" /tmp/firebase-emulator.log || [ $RETRY -ge $MAX_RETRIES ]; do
  sleep 1
  ((RETRY++))
done

if grep -q "All emulators ready" /tmp/firebase-emulator.log; then
  echo "Firestore emulator started."
else
  echo "Firestore emulator failed to start. Dumping log:" >&2
  sed -n '1,200p' /tmp/firebase-emulator.log >&2
  kill $EMULATOR_PID || true
  exit 1
fi

# Set environment variable for tests so they connect to emulator
export FIRESTORE_EMULATOR_HOST=localhost:8080
export FIREBASE_AUTH_EMULATOR_HOST=localhost:9099

# Run flutter tests
cd "$ROOT_DIR/housekeepr"
echo "Checking for connected Flutter devices..."
if flutter devices --machine | grep -q '"platformType".*android\|ios'; then
  echo "Device found — running integration tests."
  flutter test integration_test
else
  echo "No Android/iOS device found — running unit/widget tests only."
  flutter test
fi
TEST_EXIT=$?

# Teardown emulator
echo "Stopping emulator (pid $EMULATOR_PID)"
kill $EMULATOR_PID || true
wait $EMULATOR_PID 2>/dev/null || true

exit $TEST_EXIT
