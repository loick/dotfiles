defaults write com.apple.finder QuitMenuItem -bool true
echo "✔ Finder may be quit"

defaults write com.apple.finder AppleShowAllFiles true
echo "✔ Dotfiles shown in Finder"

defaults write com.apple.dock static-only -bool true
echo "✔ Dock now only show active applications"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
echo "✔ Tap to click configured"

defaults write com.apple.LaunchServices LSQuarantine -bool false
echo "✔ 'Are you sure you want to open this application?' dialog disabled"

defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
echo "✔ Press-and-hold accent popup disabled (key repeat instead)"

defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0
defaults write NSGlobalDomain com.apple.trackpad.forceClick -bool false
echo "✔ Look Up & Data Detectors disabled (three-finger tap and force click)"

defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write NSGlobalDomain AppleWindowTabbingMode -string "manual"
echo "✔ Finder status bar and path bar enabled, tab bar disabled"

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
echo "✔ .DS_Store disabled on network and USB drives"

defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
echo "✔ Finder defaults to list view"

mkdir -p "$HOME/Desktop/screenshots"
defaults write com.apple.screencapture location -string "$HOME/Desktop/screenshots"
echo "✔ Screenshots saved to ~/Desktop/screenshots"
