#!/bin/bash
#
# Bootstrap a fresh macOS machine: Homebrew, this repo, chezmoi, then `chezmoi init --apply`.
# Safe to re-run; each step is skipped when already done.
#
# Environment:
#   DOTFILES_ASSUME_YES=1   skip the confirmation prompt (for CI)
#   NO_COLOR=1              disable colours
#
# Must stay compatible with the bash 3.2 that ships with macOS and have no dependencies.

set -euo pipefail

GITHUB_USER="pbeam1992"
REPO_NAME="dotfiles"
HTTPS_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
SSH_URL="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"
DOTFILES_DIR="${HOME}/Repositories/github.com/${GITHUB_USER}/${REPO_NAME}"
DOTFILES_DIR_SHORT="~${DOTFILES_DIR#"${HOME}"}"

# GitHub's published ed25519 host key (fingerprint SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU).
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
GITHUB_HOST_KEY="github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"

TOTAL_STEPS=4
STEP=0
LOG=""
FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
RULE="────────────────────────────────────────────────────────────"

# --- UI -------------------------------------------------------------------------------------

IS_TTY=""
[[ -t 1 ]] && IS_TTY=1

if [[ -n "${IS_TTY}" && -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\033[1m' DIM=$'\033[2m' RESET=$'\033[0m'
  RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' BLUE=$'\033[34m'
else
  BOLD="" DIM="" RESET="" RED="" GREEN="" YELLOW="" BLUE=""
fi

banner() {
  printf '\n  %s%s bootstrap%s\n' "${BOLD}" "${REPO_NAME}" "${RESET}"
  printf '  %sgithub.com/%s/%s  →  %s%s\n' \
    "${DIM}" "${GITHUB_USER}" "${REPO_NAME}" "${DOTFILES_DIR_SHORT}" "${RESET}"
}

step() {
  STEP=$((STEP + 1))
  printf '\n  %s[%d/%d]%s %s%s%s\n' \
    "${DIM}" "${STEP}" "${TOTAL_STEPS}" "${RESET}" "${BOLD}" "$1" "${RESET}"
}

ok() { printf '        %s✔%s %s\n' "${GREEN}" "${RESET}" "$*"; }
warn() { printf '        %s!%s %s\n' "${YELLOW}" "${RESET}" "$*"; }
note() { printf '        %s%s%s\n' "${DIM}" "$*" "${RESET}"; }

die() {
  printf '        %s✘%s %s\n' "${RED}" "${RESET}" "$*" >&2
  if [[ -n "${LOG}" && -s "${LOG}" ]]; then
    printf '\n  %sLast lines of the log:%s\n' "${DIM}" "${RESET}" >&2
    tail -n 15 "${LOG}" | sed 's/^/    /' >&2
    printf '\n  %sFull log: %s%s\n' "${DIM}" "${LOG}" "${RESET}" >&2
  fi
  exit 1
}

elapsed() {
  local secs=$1
  if ((secs >= 60)); then
    printf '%dm %ds' $((secs / 60)) $((secs % 60))
  else
    printf '%ds' "${secs}"
  fi
}

# run_quiet <label> <done-message> <command...>
# Runs a command that needs no input: output goes to the log, a spinner shows progress.
run_quiet() {
  local label="$1" done_msg="$2"
  shift 2
  local start=${SECONDS} pid i=0 took

  printf '\n$ %s\n' "$*" >>"${LOG}"

  if [[ -n "${IS_TTY}" ]]; then
    "$@" >>"${LOG}" 2>&1 &
    pid=$!
    printf '\033[?25l'
    while kill -0 "${pid}" 2>/dev/null; do
      printf '\r\033[K        %s%s%s %s %s(%s)%s' \
        "${BLUE}" "${FRAMES[i % ${#FRAMES[@]}]}" "${RESET}" "${label}" \
        "${DIM}" "$(elapsed $((SECONDS - start)))" "${RESET}"
      i=$((i + 1))
      sleep 0.1
    done
    printf '\r\033[K\033[?25h'
    wait "${pid}" || die "${label} failed"
  else
    note "${label}..."
    "$@" >>"${LOG}" 2>&1 || die "${label} failed"
  fi

  took=$((SECONDS - start))
  ok "${done_msg} ${DIM}($(elapsed "${took}"))${RESET}"
}

# run_visible <label> <done-message> <command...>
# Runs a command that may ask for input (sudo password, chezmoi prompts): output is shown.
run_visible() {
  local label="$1" done_msg="$2"
  shift 2
  local start=${SECONDS} status=0

  note "${label}"
  printf '  %s%s%s\n' "${DIM}" "${RULE}" "${RESET}"
  "$@" || status=$?
  printf '  %s%s%s\n' "${DIM}" "${RULE}" "${RESET}"

  ((status == 0)) || die "${label} failed (exit ${status})"
  ok "${done_msg} ${DIM}($(elapsed $((SECONDS - start))))${RESET}"
}

confirm() {
  local answer=""
  [[ "${DOTFILES_ASSUME_YES:-}" == "1" ]] && return 0
  printf '        %s?%s %s %s[y/N]%s ' "${BLUE}" "${RESET}" "$1" "${DIM}" "${RESET}"
  { read -r answer </dev/tty; } 2>/dev/null || { answer="" && printf '\n'; }
  case "${answer}" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

restore_cursor() { [[ -n "${IS_TTY}" ]] && printf '\033[?25h'; return 0; }

# --- Steps ----------------------------------------------------------------------------------

load_brew() {
  local prefix
  for prefix in /opt/homebrew /usr/local; do
    if [[ -x "${prefix}/bin/brew" ]]; then
      eval "$("${prefix}/bin/brew" shellenv)"
      return 0
    fi
  done
  return 1
}

install_homebrew() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

step_homebrew() {
  step "Homebrew"
  if load_brew; then
    ok "Already installed ${DIM}($(brew --prefix))${RESET}"
    return
  fi
  # The installer asks for your password and installs the Xcode Command Line Tools (git).
  run_visible "Running the Homebrew installer (it will ask for your password)" \
    "Installed Homebrew" install_homebrew
  load_brew || die "Homebrew was installed but brew could not be found"
}

step_repository() {
  step "Repository"
  if [[ -d "${DOTFILES_DIR}/.git" ]]; then
    ok "Already cloned ${DIM}(${DOTFILES_DIR_SHORT})${RESET}"
  elif [[ -e "${DOTFILES_DIR}" && -n "$(ls -A "${DOTFILES_DIR}")" ]]; then
    die "${DOTFILES_DIR_SHORT} exists but is not a git repository"
  else
    mkdir -p "$(dirname "${DOTFILES_DIR}")"
    run_quiet "Cloning ${HTTPS_URL}" "Cloned to ${DOTFILES_DIR_SHORT}" \
      git clone "${HTTPS_URL}" "${DOTFILES_DIR}"
  fi
  # Fetch stays on HTTPS (no key needed for a public repo); pushes go over SSH.
  git -C "${DOTFILES_DIR}" remote set-url --push origin "${SSH_URL}"
  ok "Fetch over HTTPS, push over SSH"
  trust_github_host
}

# Without GitHub's host key in known_hosts, the first SSH push fails with
# "Host key verification failed". The key is pinned above rather than fetched.
trust_github_host() {
  local known_hosts="${HOME}/.ssh/known_hosts"
  if ssh-keygen -F github.com -f "${known_hosts}" >/dev/null 2>&1; then
    ok "GitHub's SSH host key already trusted"
    return
  fi
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  printf '%s\n' "${GITHUB_HOST_KEY}" >>"${known_hosts}"
  chmod 600 "${known_hosts}"
  ok "Added GitHub's SSH host key to known_hosts"
}

step_chezmoi() {
  step "chezmoi"
  if command -v chezmoi >/dev/null 2>&1; then
    ok "Already installed ${DIM}($(chezmoi --version | awk '{print $3}' | tr -d ','))${RESET}"
    return
  fi
  run_quiet "Installing chezmoi with Homebrew" "Installed chezmoi" brew install chezmoi
}

step_apply() {
  local init_cmd=(chezmoi init --source "${DOTFILES_DIR}" --apply)

  step "Apply dotfiles"
  note "${init_cmd[*]}"
  if ! confirm "Apply your dotfiles now?"; then
    warn "Skipped. Run this when you are ready:"
    printf '\n          %s\n\n' "${init_cmd[*]}"
    exit 0
  fi
  run_visible "Applying dotfiles" "Dotfiles applied" "${init_cmd[@]}"
}

summary() {
  printf '\n  %s✔ All done%s %sin %s%s\n\n' \
    "${GREEN}${BOLD}" "${RESET}" "${DIM}" "$(elapsed "${SECONDS}")" "${RESET}"
  printf '    %sSource%s  %s\n' "${DIM}" "${RESET}" "${DOTFILES_DIR_SHORT}"
  printf '    %sLog%s     %s\n' "${DIM}" "${RESET}" "${LOG}"
  printf '    %sNext%s    open a new terminal, then try: chezmoi cd\n\n' "${DIM}" "${RESET}"
}

main() {
  [[ "$(uname -s)" == "Darwin" ]] || {
    printf 'error: this script only supports macOS\n' >&2
    exit 1
  }

  LOG="$(mktemp "${TMPDIR:-/tmp}/dotfiles-init.XXXXXX")"
  trap restore_cursor EXIT
  trap 'restore_cursor; printf "\n"; exit 130' INT

  banner
  step_homebrew
  step_repository
  step_chezmoi
  step_apply
  summary
}

# Run main when executed (including via `bash -c "$(curl ...)"`), but not when sourced.
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
