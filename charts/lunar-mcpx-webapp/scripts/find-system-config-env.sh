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

# Resolve the namespace kubectl will actually use, for the banner below.
if command -v kubectl >/dev/null; then
  if [ -n "$NAMESPACE" ]; then
    EFFECTIVE_NS="$NAMESPACE (from argument)"
  else
    ctx_ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)
    EFFECTIVE_NS="${ctx_ns:-default} (from current context$([ -z "$ctx_ns" ] && echo ", implicit default"))"
  fi
else
  EFFECTIVE_NS="n/a (kubectl not found - secret inspection skipped)"
fi

# Colors (disabled when not a TTY)
if [ -t 1 ]; then
  BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; DIM=$'\033[2m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
  BOLD=""; GREEN=""; YELLOW=""; CYAN=""; DIM=""; RED=""; RESET=""
fi

KEY_PATTERN='HIVE_DEFAULT_LOG_LEVEL|HIVE_DEFAULT_STRICTNESS_REQUIRED|HIVE_DEFAULT_ENABLE_PROMPT_CAPABILITY|HIVE_DEFAULT_ENABLE_SKILL_SCOPING|ENABLE_AUTO_PROVISIONING|ENABLE_STDIO_MCP_SERVERS|HIBERNATION_ENABLED|HIBERNATION_IDLE_MINUTES|LLM_PROVIDER|LLM_MODEL|LLM_API_KEY|AUDIT_LOG_ENABLED|AUDIT_LOG_RETENTION_DAYS|HIVE_ENABLE_DIND|HIVE_DEFAULT_CPU_REQUEST|HIVE_DEFAULT_CPU_LIMIT|HIVE_DEFAULT_MEMORY_REQUEST|HIVE_DEFAULT_MEMORY_LIMIT'

# Deprecated names for the LLM_* keys; matched values migrate under the new name.
OLD_KEY_PATTERN='SANDBOX_ANALYSIS_LLM_PROVIDER|SANDBOX_ANALYSIS_LLM_MODEL|SANDBOX_ANALYSIS_LLM_API_KEY'
canonical_key() { echo "${1/#SANDBOX_ANALYSIS_LLM_/LLM_}"; }

SCOPES="global webserver hub admin auth controller router jobs"

section() { echo; echo "${BOLD}${CYAN}== $1 ==${RESET}"; }
none() { echo "${DIM}(none found)${RESET}"; }

LITERALS=()      # "KEY: value   # source" (incl. knob-implied)
SECRET_REFS=()   # "KEY|secretName|secretKey"
FROM_SECRETS=()  # secret names containing a system-config key
# Sandbox-analysis-origin entries, kept separate: they configured sandbox
# analysis until now, so on a key conflict they win (emitted first, dedupe
# keeps the first occurrence).
SANDBOX_LITERALS=()
SANDBOX_SECRET_REFS=()

echo "${BOLD}Values file:${RESET} ${VALUES_FILE}"
echo "${BOLD}Namespace:${RESET}   ${EFFECTIVE_NS}"

section "Literal env vars (will go into jobs.admin.seedSystemConfig)"
for scope in $SCOPES; do
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      SANDBOX_ANALYSIS_LLM_*) SANDBOX_LITERALS+=("$(canonical_key "$line")") ;;
      *) LITERALS+=("$line") ;;
    esac
    line=$(canonical_key "$line")
    echo "${GREEN}${line%%#*}${RESET}${DIM}#${line#*#}${RESET}"
  done < <(yq -r ".${scope}.extraEnvVars[]? | select(.value != null) | .name + \": \" + (.value | tostring) + \"   # found in ${scope}.extraEnvVars\"" "$VALUES_FILE" | grep -E "^(${KEY_PATTERN}|${OLD_KEY_PATTERN}): " || true)
done
# Implicit chart knobs render as env vars too — same copy-into-seed treatment.
idle=$(yq -r '.hibernation.idleMinutes // ""' "$VALUES_FILE")
if [ -n "$idle" ] && [ "$idle" != "0" ]; then
  LITERALS+=("HIBERNATION_ENABLED: true   # implied by hibernation.idleMinutes" "HIBERNATION_IDLE_MINUTES: ${idle}   # implied by hibernation.idleMinutes")
  echo "${GREEN}HIBERNATION_ENABLED: true${RESET}   ${DIM}# implied by hibernation.idleMinutes${RESET}"
  echo "${GREEN}HIBERNATION_IDLE_MINUTES: ${idle}${RESET}   ${DIM}# implied by hibernation.idleMinutes${RESET}"
fi
retention=$(yq -r '.auditLog.retentionDays // ""' "$VALUES_FILE")
if [ -n "$retention" ]; then
  LITERALS+=("AUDIT_LOG_RETENTION_DAYS: ${retention}   # implied by auditLog.retentionDays")
  echo "${GREEN}AUDIT_LOG_RETENTION_DAYS: ${retention}${RESET}   ${DIM}# implied by auditLog.retentionDays${RESET}"
fi
provider=$(yq -r '.webserver.sandboxAnalysis.llmProvider // ""' "$VALUES_FILE")
if [ -n "$provider" ]; then
  SANDBOX_LITERALS+=("LLM_PROVIDER: ${provider}   # implied by webserver.sandboxAnalysis.llmProvider (deprecated)")
  echo "${GREEN}LLM_PROVIDER: ${provider}${RESET}   ${DIM}# implied by webserver.sandboxAnalysis.llmProvider (deprecated)${RESET}"
fi
model=$(yq -r '.webserver.sandboxAnalysis.llmModel // ""' "$VALUES_FILE")
if [ -n "$model" ]; then
  SANDBOX_LITERALS+=("LLM_MODEL: ${model}   # implied by webserver.sandboxAnalysis.llmModel (deprecated)")
  echo "${GREEN}LLM_MODEL: ${model}${RESET}   ${DIM}# implied by webserver.sandboxAnalysis.llmModel (deprecated)${RESET}"
fi
[ $((${#LITERALS[@]} + ${#SANDBOX_LITERALS[@]})) -eq 0 ] && none

section "Env vars referencing a secret (will be wired to the job, value stays in the secret)"
for scope in $SCOPES; do
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    IFS='|' read -r k s sk <<< "$line"
    case "$k" in
      SANDBOX_ANALYSIS_LLM_*) SANDBOX_SECRET_REFS+=("$(canonical_key "$k")|${s}|${sk}") ;;
      *) SECRET_REFS+=("${k}|${s}|${sk}") ;;
    esac
    k=$(canonical_key "$k")
    echo "${YELLOW}${k}: secret ${s}/${sk}${RESET}   ${DIM}# found in ${scope}.extraEnvVars${RESET}"
  done < <(yq -r ".${scope}.extraEnvVars[]? | select(.valueFrom.secretKeyRef != null) | .name + \"|\" + .valueFrom.secretKeyRef.name + \"|\" + .valueFrom.secretKeyRef.key" "$VALUES_FILE" | grep -E "^(${KEY_PATTERN}|${OLD_KEY_PATTERN})\|" || true)
done
[ $((${#SECRET_REFS[@]} + ${#SANDBOX_SECRET_REFS[@]})) -eq 0 ] && none

section "Injected secrets (keys matching a system-config env var are flagged)"
found=0
for scope in $SCOPES; do
  for secret in $(yq -r ".${scope}.extraEnvFromSecrets[]?" "$VALUES_FILE"); do
    found=1
    echo "${scope}.extraEnvFromSecrets: ${BOLD}${secret}${RESET}"
    if command -v kubectl >/dev/null; then
      keys=$(kubectl "${NS_ARGS[@]+"${NS_ARGS[@]}"}" get secret "$secret" -o jsonpath='{.data}' 2>/dev/null | yq -p=json -r 'keys | .[]' 2>/dev/null) || keys=""
      if [ -z "$keys" ]; then
        if [ -z "$NAMESPACE" ]; then
          echo "    ${YELLOW}(could not read secret - is the right namespace set? pass it as the 2nd arg or set your context)${RESET}"
        else
          echo "    ${YELLOW}(could not read secret in namespace ${NAMESPACE} - inspect manually)${RESET}"
        fi
        continue
      fi
      while IFS= read -r key; do
        if echo "$key" | grep -qE "^(${KEY_PATTERN})$"; then
          FROM_SECRETS+=("$secret")
          echo "    ${YELLOW}key: ${key}   <-- system-config key, will be wired to the job${RESET}"
        elif echo "$key" | grep -qE "^(${OLD_KEY_PATTERN})$"; then
          SANDBOX_SECRET_REFS+=("$(canonical_key "$key")|${secret}|${key}")
          echo "    ${YELLOW}key: ${key}   <-- deprecated system-config key, will be wired to the job as $(canonical_key "$key")${RESET}"
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
if [ $((${#LITERALS[@]} + ${#SANDBOX_LITERALS[@]} + ${#SECRET_REFS[@]} + ${#SANDBOX_SECRET_REFS[@]} + ${#FROM_SECRETS[@]})) -eq 0 ]; then
  echo "${DIM}(nothing to migrate — no system-config env vars found)${RESET}"
else
  echo "jobs:"
  if [ $((${#LITERALS[@]} + ${#SANDBOX_LITERALS[@]})) -gt 0 ]; then
    echo "  admin:"
    echo "    seedSystemConfig:"
    printf '%s\n' ${SANDBOX_LITERALS[@]+"${SANDBOX_LITERALS[@]}"} ${LITERALS[@]+"${LITERALS[@]}"} |
      awk -F': ' '!seen[$1]++ { print "      " $0; next } { print "      # duplicate " $1 " ignored (kept first): " $0 }'
  fi
  if [ $((${#SECRET_REFS[@]} + ${#SANDBOX_SECRET_REFS[@]})) -gt 0 ]; then
    echo "  extraEnvVars:"
    while IFS='|' read -r k s sk; do
      [ -z "$k" ] && continue
      echo "    - name: ${k}"
      echo "      valueFrom:"
      echo "        secretKeyRef:"
      echo "          name: ${s}"
      echo "          key: ${sk}"
    done < <(printf '%s\n' ${SANDBOX_SECRET_REFS[@]+"${SANDBOX_SECRET_REFS[@]}"} ${SECRET_REFS[@]+"${SECRET_REFS[@]}"} | awk -F'|' '!seen[$1]++')
    printf '%s\n' ${SANDBOX_SECRET_REFS[@]+"${SANDBOX_SECRET_REFS[@]}"} ${SECRET_REFS[@]+"${SECRET_REFS[@]}"} |
      awk -F'|' 'seen[$1]++ { print "    # duplicate " $1 " ref ignored (kept first): secret " $2 "/" $3 }'
  fi
  if [ ${#FROM_SECRETS[@]} -gt 0 ]; then
    echo "  extraEnvFromSecrets:"
    printf '    - %s\n' "${FROM_SECRETS[@]}" | sort -u
  fi
fi
