class Lokishell < Formula
  include Language::Python::Virtualenv

  desc "Separate work and personal CLI accounts by folder"
  homepage "https://github.com/ccosnean/lokishell"
  url "https://github.com/ccosnean/lokishell/releases/download/v0.4.0/lokishell-0.4.0.tar.gz"
  sha256 "0edec229dfd18c3c7bbc81940e69bdff78362f8eb9e9133bdadee217a1dca569"
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
    doc.install "README.md", "CONTRIBUTING.md", "requirements.txt"
    inreplace bin/"loki", "#!/usr/bin/env python3", "#!#{libexec}/venv/bin/python"
  end

  def caveats
    <<~EOS
      Run `loki use personal --global` to choose your global persona.
      Run `loki use` in a project, or `loki use work` for a folder override.
      Open a fresh terminal once after the first shell setup.
      Use `loki tools list` to browse integrations and `loki add TOOL` to connect an account.
    EOS
  end

  test do
    assert_match "LokiShell 0.4.0", shell_output("#{bin}/loki --version")
    ENV["LOKI_HOME"] = (testpath/"settings").to_s
    ENV["DIRENV_CONFIG"] = (testpath/"direnv").to_s
    ENV["XDG_DATA_HOME"] = (testpath/"data").to_s
    system bin/"loki", "tools", "validate"
    system bin/"loki", "create", "personal"
    system bin/"loki", "use", "personal", "--global", "--no-shell"
    system bin/"loki", "tools", "install", "firebase"
    assert_match "Validated 2 tool definitions", shell_output("#{bin}/loki tools validate")
    assert_match "Contribute your tool", shell_output("#{bin}/loki tools list")
    (testpath/"project").mkpath
    cd testpath/"project" do
      system bin/"loki", "use", "--no-shell"
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
