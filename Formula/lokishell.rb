class Lokishell < Formula
  desc "Separate work and personal CLI accounts by folder"
  homepage "https://github.com/ccosnean/lokishell"
  url "https://github.com/ccosnean/lokishell/releases/download/v0.3.0/lokishell-0.3.0.tar.gz"
  sha256 "f6220ae74e0586abf4a2df99b06da349e8c6e8465ac31962863637aba6d90a27"
  license "MIT"

  depends_on "direnv"
  depends_on "python@3.14"

  conflicts_with "loki", because: "both install a loki executable"

  def install
    bin.install "bin/loki"
    libexec.install "lib", "tools"
    doc.install "README.md", "CONTRIBUTING.md"
    inreplace bin/"loki", "#!/usr/bin/env python3", "#!#{Formula["python@3.14"].opt_bin}/python3.14"
  end

  def caveats
    <<~EOS
      Run `loki shift personal` to choose your global persona.
      Use `loki init` in a project, or `loki use work` for a folder override.
      Open a fresh terminal once after the first shell setup.
      Use `loki tools list` to browse integrations and `loki add TOOL` to connect an account.
    EOS
  end

  test do
    assert_match "LokiShell 0.3.0", shell_output("#{bin}/loki --version")
    ENV["LOKI_HOME"] = (testpath/"settings").to_s
    ENV["DIRENV_CONFIG"] = (testpath/"direnv").to_s
    ENV["XDG_DATA_HOME"] = (testpath/"data").to_s
    system bin/"loki", "tools", "validate"
    system bin/"loki", "shift", "personal", "--no-shell"
    system bin/"loki", "tools", "install", "firebase"
    (testpath/"project").mkpath
    cd testpath/"project" do
      system bin/"loki", "init", "--no-shell"
      assert_match '"profile": "personal"', shell_output("#{bin}/loki status")
      assert_equal ["google", "firebase"], JSON.parse(shell_output("#{bin}/loki status"))["tools"]
      system bin/"loki", "use", "work", "--no-shell"
      assert_match '"profile": "work"', shell_output("#{bin}/loki status")
      assert_empty JSON.parse(shell_output("#{bin}/loki status"))["tools"]
      system bin/"loki", "clean"
      refute_path_exists testpath/"project/.envrc"
      assert_match '"profile": "personal"', shell_output("#{bin}/loki status")
    end
  end
end
