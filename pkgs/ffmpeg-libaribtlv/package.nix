{
  callPackage,
  fetchFromGitHub,
  lib,
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
(callPackage "${patchset}/package.nix" { inherit patchsetRevision; }).overrideAttrs (old: {
  meta = old.meta // {
    description = "FFmpeg for ARIB TLV (MMTS) support";
    homepage = "https://github.com/makeding/ffmpeg-libaribtlv";
    maintainers = [ lib.maintainers.huggy ];
  };
  passthru = (old.passthru or { }) // {
    inherit patchset;
  };
})
