class Libtrigger < Formula
  desc "Library to capture file events from kernel"
  homepage "https://github.com/krakjn/trigger"
  version "0.1.0"
  license "MIT"

  on_arm64 do
    url "https://github.com/krakjn/trigger/releases/download/v0.1.0/libtrigger-0.1.0-arm64.tar.gz"
    sha256 "FILL_IN_AFTER_CREATE"
  end

  on_intel do
    url "https://github.com/krakjn/trigger/releases/download/v0.1.0/libtrigger-0.1.0-x86_64.tar.gz"
    sha256 "FILL_IN_AFTER_CREATE"
  end

  def install
    lib.install "lib/libtrigger.dylib"
    include.install "include/trigger.h"
  end

  test do
    assert_path_exists lib/"libtrigger.dylib"
    assert_path_exists include/"trigger.h"
  end
end
