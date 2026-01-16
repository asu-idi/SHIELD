#!/usr/bin/env bash
set -euo pipefail

DISAGG=${DISAGG:-0} # Default; can be overridden via flag or env.

usage() {
  cat <<'EOF'
Usage: ./check_prereqs.sh [--disagg] [--help]

  --disagg   Require gRPC + HDFS checks (for disaggregated setups).
  --help     Show this help.

You can also set DISAGG=1 in the environment instead of using --disagg.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --disagg|--disaggregated)
      DISAGG=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

status=0

require_cmd() {
  local name="$1" cmd="$2"
  if command -v "${cmd}" >/dev/null 2>&1; then
    echo "[OK] ${name}: $(${cmd} --version 2>/dev/null | head -n1)"
  else
    echo "[FAIL] ${name}: command '${cmd}' not found"
    status=1
  fi
}

check_java11() {
  local java_bin
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    java_bin="${JAVA_HOME}/bin/java"
  elif command -v java >/dev/null 2>&1; then
    java_bin="$(command -v java)"
  else
    echo "[FAIL] Java 11: java not found (set JAVA_HOME)"
    status=1
    return
  fi

  local line major
  line="$(${java_bin} -version 2>&1 | head -n1)"
  major=$(echo "${line}" | sed -n 's/.*"\([0-9][0-9]*\)\..*/\1/p')
  if [[ "${major}" == "11" ]]; then
    echo "[OK] Java 11: ${line} (JAVA_HOME=${JAVA_HOME:-unset})"
  else
    echo "[FAIL] Java 11: found ${line} (need 11.x)"
    status=1
  fi
}

check_pkg() {
  local label="$1" pkg="$2" required="$3"
  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists "${pkg}"; then
    echo "[OK] ${label}: pkg-config ${pkg} $(pkg-config --modversion "${pkg}" 2>/dev/null)"
  else
    local tag
    tag=$([[ "${required}" == "1" ]] && echo "FAIL" || echo "WARN")
    echo "[${tag}] ${label}: not detected via pkg-config (${pkg})"
    [[ "${required}" == "1" ]] && status=1
  fi
}

echo "Checking core tools..."
require_cmd "OpenSSL" "openssl"
check_java11
require_cmd "Maven" "mvn"
require_cmd "Node.js" "node"
require_cmd "CMake" "cmake"

echo
echo "Checking compiler..."
if command -v g++ >/dev/null 2>&1; then
  gpp_ver="$(g++ -dumpfullversion -dumpversion 2>/dev/null | head -n1)"
  if [[ ${gpp_ver%%.*} -ge 7 ]]; then
    echo "[OK] g++ ${gpp_ver} (C++17-ready)"
  else
    echo "[WARN] g++ ${gpp_ver} (need >= 7 for C++17)"
  fi
elif command -v clang++ >/dev/null 2>&1; then
  clang_ver="$(clang++ --version 2>/dev/null | head -n1)"
  echo "[OK] clang++ detected: ${clang_ver}"
else
  echo "[FAIL] C++ compiler: g++/clang++ not found"
  status=1
fi

echo
echo "Checking disaggregated deps"
check_pkg "gRPC" "grpc" "${DISAGG}"
if command -v hdfs >/dev/null 2>&1 || command -v hadoop >/dev/null 2>&1; then
  echo "[OK] HDFS client detected"
else
  if [[ ${DISAGG} -eq 1 ]]; then
    echo "[FAIL] HDFS client not found"
    status=1
  else
    echo "[WARN] HDFS client not found"
  fi
fi

echo
if [[ ${status} -eq 0 ]]; then
  echo "All required checks passed."
else
  echo "One or more required checks failed."
fi

exit ${status}
