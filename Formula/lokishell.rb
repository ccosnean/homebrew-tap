class Lokishell < Formula
  include Language::Python::Virtualenv

  desc "Separate work and personal CLI accounts by folder"
  homepage "https://github.com/ccosnean/lokishell"
  url "https://github.com/ccosnean/lokishell/releases/download/v0.7.0/lokishell-0.7.0.tar.gz"
  sha256 "65d3b16fc756bead5043da84ea62594a335279c392810888a8e6e7f1fbc02fae"
  license "MIT"

  depends_on "direnv"
  depends_on "python@3.14"

  conflicts_with "loki", because: "both install a loki executable"

  resource "click" do
    url "https://files.pythonhosted.org/packages/c7/0e/7fa0ef50764b67090eca4114772a2abf8b6148198475e54c660b97caeee6/click-8.5.0.tar.gz"
    sha256 "ba0d2089de75ea0310e2dde03160e6ca10009947fb95a182f9b54021bb272e34"
  end

  def install
    venv = virtualenv_create(libexec/"venv", "python3.14")
    venv.pip_install resources
    bin.install "bin/loki"
    libexec.install "lib", "tools"
    doc.install "README.md", "CONTRIBUTING.md", "requirements.txt", "assets"
    inreplace bin/"loki", "#!/usr/bin/env python3", "#!#{libexec}/venv/bin/python"
  end

  def caveats
    <<~EOS
      Run `loki use personal --global` to choose your global persona.
      Run `loki use` in a project, or `loki use work` for a folder override.
      Open a fresh terminal once after the first shell setup.
      Use `loki tools catalog` to browse integrations and `loki add TOOL` to connect an account.
    EOS
  end

  test do
    assert_match "LokiShell #{version}", shell_output("#{bin}/loki --version")
    ENV["LOKI_HOME"] = (testpath/"settings").to_s
    ENV["DIRENV_CONFIG"] = (testpath/"direnv").to_s
    ENV["XDG_DATA_HOME"] = (testpath/"data").to_s
    system bin/"loki", "tools", "validate"
    system bin/"loki", "create", "personal"
    system bin/"loki", "use", "personal", "--global", "--no-shell"
    identity = JSON.parse(shell_output("#{bin}/loki who --json"))
    assert_equal "personal", identity["persona"]
    assert_equal "global", identity["source"]
    assert_empty identity["tools"]
    system bin/"loki", "tools", "install", "firebase"
    assert_match "Validated 2 tool definitions", shell_output("#{bin}/loki tools validate")
    assert_match "Contribute your tool", shell_output("#{bin}/loki tools catalog")
    installed = JSON.parse(shell_output("#{bin}/loki tools list --json"))
    assert_equal ["firebase"], installed["tools"].map { |tool| tool["id"] }
    identity = JSON.parse(shell_output("#{bin}/loki who --json"))
    assert_equal ["firebase"], identity["tools"].map { |tool| tool["id"] }
    ENV["XDG_CONFIG_HOME"] = (testpath/"independent-config").to_s
    (testpath/"fake-bin").mkpath
    (testpath/"fake-bin/firebase").write <<~SH
      #!/bin/sh
      printf '%s\\n' "$XDG_CONFIG_HOME"
    SH
    (testpath/"fake-bin/firebase").chmod 0755
    ENV.prepend_path "PATH", testpath/"fake-bin"
    scoped = shell_output <<~SH
      eval "$(#{bin}/loki _env personal)"
      printf '%s\\n' "$XDG_CONFIG_HOME"
      firebase
    SH
    assert_equal [(testpath/"independent-config").to_s,
                  (testpath/"settings/profiles/personal/xdg").to_s], scoped.lines.map(&:strip)
    (testpath/"project").mkpath
    cd testpath/"project" do
      system bin/"loki", "use", "--no-shell"
      assert_match '"profile": "personal"', shell_output("#{bin}/loki status")
      assert_equal ["google", "firebase"], JSON.parse(shell_output("#{bin}/loki status"))["tools"]
      system bin/"loki", "use", "work", "--no-shell"
      assert_match '"profile": "work"', shell_output("#{bin}/loki status")
      assert_empty JSON.parse(shell_output("#{bin}/loki status"))["tools"]
      identity = JSON.parse(shell_output("#{bin}/loki who --json"))
      assert_equal "work", identity["persona"]
      assert_equal "folder", identity["source"]
      assert_empty identity["tools"]
      system bin/"loki", "clean"
      refute_path_exists testpath/"project/.envrc"
      assert_match '"profile": "personal"', shell_output("#{bin}/loki status")
    end
  end
end
