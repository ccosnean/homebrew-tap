class Lokishell < Formula
  desc "Separate work and personal CLI accounts by folder"
  homepage "https://github.com/ccosnean/lokishell"
  url "https://github.com/ccosnean/lokishell/releases/download/v0.2.0/lokishell-0.2.0.tar.gz"
  sha256 "19cfb1b812c71f85753e04dac58e2ddb0f6b1f79785cec19e8fc97de2fc7f98d"
  license "MIT"

  depends_on "direnv"
  depends_on "python@3.14"

  conflicts_with "loki", because: "both install a loki executable"

  def install
    bin.install "bin/loki"
    inreplace bin/"loki", "#!/usr/bin/env python3", "#!#{Formula["python@3.14"].opt_bin}/python3.14"
  end

  def caveats
    <<~EOS
      Run `loki init` in a project and choose personal or work.
      Open a fresh terminal once after the first shell setup.
      Use `loki add SERVICE` to connect accounts for that profile.
    EOS
  end

  test do
    assert_match "LokiShell 0.2.0", shell_output("#{bin}/loki --version")
    ENV["LOKI_HOME"] = (testpath/"settings").to_s
    ENV["DIRENV_CONFIG"] = (testpath/"direnv").to_s
    ENV["XDG_DATA_HOME"] = (testpath/"data").to_s
    system bin/"loki", "shift", "personal", "--no-shell"
    (testpath/"project").mkpath
    cd testpath/"project" do
      system bin/"loki", "init", "--no-shell"
      assert_match '"profile": "personal"', shell_output("#{bin}/loki status")
      system bin/"loki", "use", "work", "--no-shell"
      assert_match '"profile": "work"', shell_output("#{bin}/loki status")
      system bin/"loki", "clean"
      refute_path_exists testpath/"project/.envrc"
      assert_match '"profile": "personal"', shell_output("#{bin}/loki status")
    end
  end
end
