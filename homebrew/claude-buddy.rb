class ClaudeBuddy < Formula
  desc "Permanent ASCII art coding companion for Claude Code"
  homepage "https://github.com/Casta-mere/Claude-Buddy"
  url "https://github.com/Casta-mere/Claude-Buddy/archive/refs/tags/v0.1.0.tar.gz"
  # sha256 will be filled after first release
  license "MIT"

  depends_on "node"
  depends_on "jq"

  def install
    system "npm", "install", "--production", "--silent"
    system "npm", "run", "build"

    # Install the bundled server and scripts
    libexec.install "dist/buddy-server.mjs"
    libexec.install Dir["plugin/*"]
    libexec.install Dir["statusline/*"]
    libexec.install Dir["scripts/*"]

    # Create a wrapper script
    (bin/"claude-buddy").write <<~EOS
      #!/bin/bash
      case "${1:-help}" in
        install)
          SOURCE_DIR="#{libexec}" bash "#{libexec}/install.sh"
          ;;
        uninstall)
          bash "#{libexec}/uninstall.sh"
          ;;
        doctor)
          bash "#{libexec}/doctor.sh"
          ;;
        show)
          node "#{libexec}/buddy-server.mjs" --show 2>/dev/null || echo "Run 'claude-buddy install' first"
          ;;
        *)
          echo "Claude Buddy - ASCII coding companion for Claude Code"
          echo ""
          echo "Usage:"
          echo "  claude-buddy install    Set up companion and configure Claude Code"
          echo "  claude-buddy uninstall  Remove companion and revert settings"
          echo "  claude-buddy doctor     Check installation health"
          echo "  claude-buddy help       Show this help"
          ;;
      esac
    EOS
  end

  def caveats
    <<~EOS
      Run 'claude-buddy install' to configure Claude Code and hatch your companion.
    EOS
  end

  test do
    assert_match "Claude Buddy", shell_output("#{bin}/claude-buddy help")
  end
end
