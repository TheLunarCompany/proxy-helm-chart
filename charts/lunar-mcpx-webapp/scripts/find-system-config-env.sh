#!/usr/bin/env bash
# ****************************************************************************
# * ACCESS DECLARATION (for security review)                                *
# *                                                                         *
# * This script is READ-ONLY. It never writes, deletes, or mutates things.  *
# *                                                                         *
# *   Reads:  the local values file passed as an argument (via yq)          *
# *   Reads:  kubernetes secrets in the target namespace (kubectl get)      *
# *           - only secret KEY NAMES are printed, never secret VALUES      *
# *   Runs:   yq, kubectl, and standard shell tools (grep, echo, printf)    *
# *                                                                         *
# * No network calls of its own. No writes to disk. No cluster mutations.   *
# * kubectl is not required; if absent or lacking access, that step is      *
# * skipped and the rest still runs.                                        *
# ****************************************************************************
#
# Lists system-config env vars set in a lunar-mcpx-webapp values file and
# prints a ready-to-paste `jobs:` section for the seed-system-config migration.
# Usage: ./find-system-config-env.sh values.override.yaml [namespace]
# Requires yq (https://github.com/mikefarah/yq). Optionally kubectl to inspect secrets.
# Namespace is optional; without it kubectl uses your current context (e.g. set via kns).
#
# Example: ./find-system-config-env.sh values.override.yaml my-namespace
set -euo pipefail

VALUES_FILE="${1:?usage: $0 <values-file> [namespace]}"
NAMESPACE="${2:-}"
NS_ARGS=()
[ -n "$NAMESPACE" ] && NS_ARGS=(-n "$NAMESPACE")

# Colors (disabled when not a TTY)
if [ -t 1 ]; then
  BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; DIM=$'\033[2m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
  BOLD=""; GREEN=""; YELLOW=""; CYAN=""; DIM=""; RED=""; RESET=""
fi

KEY_PATTERN='HIVE_DEFAULT_LOG_LEVEL|HIVE_DEFAULT_STRICTNESS_REQUIRED|HIVE_DEFAULT_ENABLE_PROMPT_CAPABILITY|HIVE_DEFAULT_ENABLE_SKILL_SCOPING|ENABLE_AUTO_PROVISIONING|ENABLE_STDIO_MCP_SERVERS|HIBERNATION_ENABLED|HIBERNATION_IDLE_MINUTES|LLM_PROVIDER|LLM_MODEL|LLM_API_KEY|AUDIT_LOG_ENABLED|AUDIT_LOG_RETENTION_DAYS|HIVE_ENABLE_DIND|HIVE_DEFAULT_CPU_REQUEST|HIVE_DEFAULT_CPU_LIMIT|HIVE_DEFAULT_MEMORY_REQUEST|HIVE_DEFAULT_MEMORY_LIMIT'

SCOPES="global webserver hub admin auth controller router jobs"

section() { echo; echo "${BOLD}${CYAN}== $1 ==${RESET}"; }
none() { echo "${DIM}(none found)${RESET}"; }

LITERALS=()      # "KEY: value" (incl. knob-implied)
SECRET_REFS=()   # "KEY|secretName|secretKey"
FROM_SECRETS=()  # secret names containing a system-config key

section "Literal env vars (will go into jobs.admin.seedSystemConfig)"
for scope in $SCOPES; do
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    LITERALS+=("${line%%   #*}")
    echo "${GREEN}${line%%#*}${RESET}${DIM}#${line#*#}${RESET}"
  done < <(yq -r ".${scope}.extraEnvVars[]? | select(.value != null) | .name + \": \" + (.value | tostring) + \"   # found in ${scope}.extraEnvVars\"" "$VALUES_FILE" | grep -E "^(${KEY_PATTERN}): " || true)
done
# Implicit chart knobs render as env vars too — same copy-into-seed treatment.
idle=$(yq -r '.hibernation.idleMinutes // ""' "$VALUES_FILE")
if [ -n "$idle" ] && [ "$idle" != "0" ]; then
  LITERALS+=("HIBERNATION_ENABLED: true" "HIBERNATION_IDLE_MINUTES: ${idle}")
  echo "${GREEN}HIBERNATION_ENABLED: true${RESET}   ${DIM}# implied by hibernation.idleMinutes${RESET}"
  echo "${GREEN}HIBERNATION_IDLE_MINUTES: ${idle}${RESET}   ${DIM}# implied by hibernation.idleMinutes${RESET}"
fi
retention=$(yq -r '.auditLog.retentionDays // ""' "$VALUES_FILE")
if [ -n "$retention" ]; then
  LITERALS+=("AUDIT_LOG_RETENTION_DAYS: ${retention}")
  echo "${GREEN}AUDIT_LOG_RETENTION_DAYS: ${retention}${RESET}   ${DIM}# implied by auditLog.retentionDays${RESET}"
fi
[ ${#LITERALS[@]} -eq 0 ] && none

section "Env vars referencing a secret (will be wired to the job, value stays in the secret)"
for scope in $SCOPES; do
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    SECRET_REFS+=("$line")
    IFS='|' read -r k s sk <<< "$line"
    echo "${YELLOW}${k}: secret ${s}/${sk}${RESET}   ${DIM}# found in ${scope}.extraEnvVars${RESET}"
  done < <(yq -r ".${scope}.extraEnvVars[]? | select(.valueFrom.secretKeyRef != null) | .name + \"|\" + .valueFrom.secretKeyRef.name + \"|\" + .valueFrom.secretKeyRef.key" "$VALUES_FILE" | grep -E "^(${KEY_PATTERN})\|" || true)
done
[ ${#SECRET_REFS[@]} -eq 0 ] && none

section "Injected secrets (keys matching a system-config env var are flagged)"
found=0
for scope in $SCOPES; do
  for secret in $(yq -r ".${scope}.extraEnvFromSecrets[]?" "$VALUES_FILE"); do
    found=1
    echo "${scope}.extraEnvFromSecrets: ${BOLD}${secret}${RESET}"
    if command -v kubectl >/dev/null; then
      keys=$(kubectl "${NS_ARGS[@]}" get secret "$secret" -o jsonpath='{.data}' 2>/dev/null | yq -p=json -r 'keys | .[]' 2>/dev/null) || keys=""
      if [ -z "$keys" ]; then
        echo "    ${DIM}(could not read secret - inspect manually)${RESET}"
        continue
      fi
      while IFS= read -r key; do
        if echo "$key" | grep -qE "^(${KEY_PATTERN})$"; then
          FROM_SECRETS+=("$secret")
          echo "    ${RED}key: ${key}   <-- system-config key, will be wired to the job${RESET}"
        else
          echo "    ${DIM}key: ${key}${RESET}"
        fi
      done <<< "$keys"
    else
      echo "    ${DIM}(kubectl not available - inspect manually)${RESET}"
    fi
  done
done
[ "$found" = 0 ] && none

section "Here's how your jobs section should look (paste into your values file)"
if [ ${#LITERALS[@]} -eq 0 ] && [ ${#SECRET_REFS[@]} -eq 0 ] && [ ${#FROM_SECRETS[@]} -eq 0 ]; then
  echo "${DIM}(nothing to migrate — no system-config env vars found)${RESET}"
else
  echo "jobs:"
  if [ ${#LITERALS[@]} -gt 0 ]; then
    echo "  admin:"
    echo "    seedSystemConfig:"
    printf '      %s\n' "${LITERALS[@]}"
  fi
  if [ ${#SECRET_REFS[@]} -gt 0 ]; then
    echo "  extraEnvVars:"
    for ref in "${SECRET_REFS[@]}"; do
      IFS='|' read -r k s sk <<< "$ref"
      echo "    - name: ${k}"
      echo "      valueFrom:"
      echo "        secretKeyRef:"
      echo "          name: ${s}"
      echo "          key: ${sk}"
    done
  fi
  if [ ${#FROM_SECRETS[@]} -gt 0 ]; then
    echo "  extraEnvFromSecrets:"
    printf '    - %s\n' "${FROM_SECRETS[@]}" | sort -u
  fi
fi
