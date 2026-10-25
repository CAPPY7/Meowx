cask "meowx" do
  version "1.0.0"
  sha256 "REPLACED_BY_RELEASE_WORKFLOW"

  url "https://github.com/Cappy7/Meowx/releases/download/v#{version}/Meowx-#{version}.dmg"
  depends_on arch: :arm64
  depends_on macos: ">= :tahoe"

  name "Meowx"
  desc "Free open source media player for macOS"
  homepage "https://github.com/Cappy7/Meowx"

  app "Meowx.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Meowx.app"]
  end

  zap trash: "~/Library/Application Support/Meowx"
end
