{
  callPackage,
  fetchFromGitHub,
  lib,
  ffmpeg_8-headless,
}:

let
  patchsetRevision = "a1bb0275994e611ca996bdb678f680ba328fdbff";
  patchset = fetchFromGitHub {
    owner = "makeding";
    repo = "ffmpeg-libaribtlv";
    rev = patchsetRevision;
    hash = "sha256-HUrCO9rVFTp9fwoZWvtSbE+cOOfSu+hkh+ORJ9UupJQ=";
  };
in
(callPackage "${patchset}/package.nix" {
  inherit patchsetRevision;
  # The patchset changes libavcodec's ABI and test makefiles at this exact
  # baseline; following Nixpkgs' rolling FFmpeg 8 release breaks patching.
  ffmpeg_8-headless = ffmpeg_8-headless.override {
    version = "8.1.2";
    withGrayscale = true;
    source = fetchFromGitHub {
      owner = "FFmpeg";
      repo = "FFmpeg";
      rev = "n8.1.2";
      hash = "sha256-wJ3c8VVo/tK84K7bKYs/UWcln4mSO+tf/w5NLNjKhiI=";
    };
  };
}).overrideAttrs (old: {
  meta = old.meta // {
    description = "FFmpeg for ARIB TLV (MMTS) support";
    homepage = "https://github.com/makeding/ffmpeg-libaribtlv";
    maintainers = [ lib.maintainers.huggy ];
  };
  passthru = (old.passthru or { }) // {
    inherit patchset;
  };
})
