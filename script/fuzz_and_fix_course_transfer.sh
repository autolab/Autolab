#!/usr/bin/env bash

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ATTEMPTS_PER_ROUND=30
readonly AVERAGE_OBJECTS="${1:-${FUZZ_AVERAGE_OBJECTS:-100}}"
readonly MAX_ROUNDS="${2:-${FUZZ_MAX_ROUNDS:-0}}"
readonly LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/course-transfer-fuzz.XXXXXX")"

cleanup() {
  rm -rf "${LOG_DIR}"
}
trap cleanup EXIT INT TERM

if ! [[ "${AVERAGE_OBJECTS}" =~ ^[0-9]+$ ]] || ((AVERAGE_OBJECTS < 8)); then
  echo "average objects must be an integer of at least 8" >&2
  exit 64
fi

if ! [[ "${MAX_ROUNDS}" =~ ^[0-9]+$ ]]; then
  echo "maximum rounds must be a non-negative integer" >&2
  exit 64
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex is not installed or is not on PATH" >&2
  exit 69
fi

round=1
while :; do
  if ((MAX_ROUNDS > 0 && round > MAX_ROUNDS)); then
    echo "Stopped after ${MAX_ROUNDS} rounds without a clean fuzz run." >&2
    exit 1
  fi

  fuzz_log="${LOG_DIR}/fuzz-round-${round}.log"
  repair_log="${LOG_DIR}/codex-round-${round}.log"

  echo
  echo "=== Fuzz round ${round}: ${ATTEMPTS_PER_ROUND} attempts, average ${AVERAGE_OBJECTS} objects ==="
  (
    cd "${REPO_ROOT}" || exit 1
    bundle exec ruby script/course_transfer_fuzzer \
      --attempts "${ATTEMPTS_PER_ROUND}" \
      --average-objects "${AVERAGE_OBJECTS}"
  ) 2>&1 | tee "${fuzz_log}"
  fuzz_status=${PIPESTATUS[0]}

  if ((fuzz_status == 0)); then
    echo
    echo "Course-transfer fuzzer passed all ${ATTEMPTS_PER_ROUND} attempts."
    exit 0
  fi

  echo
  echo "=== Codex repair round ${round} ==="
  codex_command=(
    codex
    -C "${REPO_ROOT}"
    --dangerously-bypass-approvals-and-sandbox
  )
  if [[ -n "${CODEX_MODEL:-}" ]]; then
    codex_command+=(-m "${CODEX_MODEL}")
  fi
  codex_command+=(exec --ephemeral -)

  {
    cat <<'PROMPT'
The course import/export fuzzer failed. Diagnose every distinct failure in the
attached output and implement fixes in this repository. Fix the underlying
course-transfer implementation when the failure is real; do not weaken the
fuzzer, skip generated cases, or normalize substantive data differences merely
to make the run green. Preserve unrelated working-tree changes. Run focused
tests and deterministic failing-seed reproductions as appropriate. Do not only
explain the issue: make and verify the code changes so the next fuzz round has
a reasonable chance to pass.

Here is the complete fuzzer output:

PROMPT
    cat "${fuzz_log}"
  } | "${codex_command[@]}" 2>&1 | tee "${repair_log}"
  codex_status=${PIPESTATUS[1]}

  if ((codex_status != 0)); then
    saved_logs="${REPO_ROOT}/tmp/course-transfer-fuzz-failed-round-${round}"
    mkdir -p "${saved_logs}"
    cp "${fuzz_log}" "${repair_log}" "${saved_logs}/"
    echo >&2
    echo "Codex failed with status ${codex_status}; stopping to avoid a no-progress loop." >&2
    echo "Logs preserved in ${saved_logs}" >&2
    exit "${codex_status}"
  fi

  round=$((round + 1))
done
