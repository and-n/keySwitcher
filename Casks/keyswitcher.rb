# Homebrew cask template. To publish your own tap:
#   1. Create a repo named `homebrew-tap` on GitHub.
#   2. Put this file at `Casks/keyswitcher.rb`.
#   3. Fill in the version, url and sha256 for each release.
#   4. Users install with:  brew install --cask <you>/tap/keyswitcher
#
# `depends_on macos` and the quarantine note matter because the build is not
# yet notarized (no Developer ID). Once notarized, drop the `postflight`.
cask "keyswitcher" do
  version "0.1.0"
  sha256 :no_check # replace with the release DMG sha256

  url "https://github.com/OWNER/keySwitcher/releases/download/v#{version}/keySwitcher.dmg"
  name "keySwitcher"
  desc "Fixes text typed in the wrong keyboard layout"
  homepage "https://github.com/OWNER/keySwitcher"

  depends_on macos: ">= :ventura"

  app "keySwitcher.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/keySwitcher.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.tonevitskiy.keySwitcher.plist",
  ]
end
