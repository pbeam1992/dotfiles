#!/bin/bash
#
# macOS preferences. chezmoi runs this once on a new machine and again whenever this file
# changes. It sorts after install-packages, so the apps pinned to the Dock already exist.
#
# Some settings (key repeat, appearance, trackpad) only take effect after logging out.

set -euo pipefail

echo "Applying macOS preferences..."

# --- Keyboard and typing -----------------------------------------------------------------

# Fast key repeat with a short delay; holding a key repeats it instead of showing accents.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# No automatic rewriting of what is typed.
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# --- Trackpad and appearance -------------------------------------------------------------

# Fastest tracking speed.
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3

# Light by day, dark by night.
defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool true

# --- Finder ------------------------------------------------------------------------------

defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search the current folder
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder NewWindowTarget -string "PfHm"        # new windows open home
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# No .DS_Store files on network and USB volumes.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Save dialogs open expanded.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# --- Screenshots -------------------------------------------------------------------------

mkdir -p "${HOME}/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Screenshots"

# --- Menu bar ----------------------------------------------------------------------------

defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true

# --- Dock --------------------------------------------------------------------------------

defaults write com.apple.dock autohide -bool false
defaults write com.apple.dock tilesize -int 26  # small, but notification badge counts stay readable
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 64   # icon size under the pointer
defaults write com.apple.dock orientation -string "right"
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false   # keep Spaces in a fixed order

# Pinned apps, in order. Finder is always first and cannot be removed, so it is not listed.
# For each entry the first path that exists is used; an app that is not installed is skipped.
dock_apps=(
  "/Applications/Google Chrome.app"
  "/Applications/Herdr.app:${HOME}/Applications/Herdr.app"
  "/System/Applications/System Settings.app"
  "/System/Applications/Reminders.app"
  "/System/Applications/Music.app"
  "/System/Applications/iPhone Mirroring.app"
)

defaults write com.apple.dock persistent-apps -array
for entry in "${dock_apps[@]}"; do
  found=""
  IFS=':' read -r -a candidates <<<"${entry}"
  for app in "${candidates[@]}"; do
    if [[ -d "${app}" ]]; then
      found="${app}"
      break
    fi
  done
  if [[ -z "${found}" ]]; then
    echo "  skipping Dock app (not installed): ${candidates[0]}" >&2
    continue
  fi
  url="file://$(printf '%s' "${found}" | sed 's/ /%20/g')/"
  defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${url}</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>"
done

# --- Reload ------------------------------------------------------------------------------

for app in Dock Finder SystemUIServer ControlCenter; do
  killall "${app}" >/dev/null 2>&1 || true
done

echo "macOS preferences applied. Log out and back in for keyboard and trackpad changes."
