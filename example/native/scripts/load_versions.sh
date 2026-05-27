#!/usr/bin/env bash
# Читает versions.inc (?= / :=) в переменные окружения. Не source versions.mk в bash.

load_versions_inc() {
  local inc="${1:?versions.inc path}"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    local key="${line%%[[:space:]]*}"
    local rest="${line#"$key"}"
    rest="${rest#"${rest%%[![:space:]]*}"}"

    local val=
    if [[ "$rest" == ?=* ]]; then
      val="${rest#?=}"
    elif [[ "$rest" == :=* ]]; then
      val="${rest#:=}"
    else
      continue
    fi
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"

    if [[ -z "${!key:-}" ]]; then
      export "$key=$val"
    fi
  done <"$inc"
}
