{ config, lib, ... }:
let
  hasTuner = builtins.any (t: t.enable && t.mode != null && builtins.elem "BS4K" t.mode) config.dtv.tuners;
in
{
  options.dtv.bs4k = lib.mkOption {
    type = lib.types.bool;
    default = hasTuner;
    defaultText = lib.literalExpression ''any enabled dtv.tuners entry with "BS4K" in mode'';
    description = "Use the ARIB TLV/MMTS FFmpeg and rebuild DTV media consumers against it. Enabled BS4K tuners require this; enable manually for remote streams or recordings.";
  };

  config = {
    assertions = [{
      assertion = !hasTuner || config.dtv.bs4k;
      message = "An enabled BS4K tuner requires dtv.bs4k; remove the explicit false value.";
    }];
    nixpkgs.overlays = lib.mkIf config.dtv.bs4k (lib.mkAfter [
      (final: prev:
        let
          ffmpeg = final.ffmpeg-libaribtlv;
        in
        {
          # Keep the change scoped to DTV consumers. Rebuild linked libav users
          # as well as replacing FFmpeg/FFprobe command paths.
          tsreplace = prev.tsreplace.override { inherit ffmpeg; };
          qsvencc = prev.qsvencc.override { inherit ffmpeg; };
          nvencc = prev.nvencc.override { inherit ffmpeg; fromSource = true; };
          amatsukaze = prev.amatsukaze.override { inherit ffmpeg; bs4k = true; };
          honomitv = prev.honomitv.override { ffmpeg-headless = ffmpeg; };
          konomitv = prev.konomitv.override { ffmpeg-headless = ffmpeg; };
          epgstation-h = prev.epgstation-h.override { ffmpeg-headless = ffmpeg; };
          epgstation-upstream = prev.epgstation-upstream.override { ffmpeg-headless = ffmpeg; };
          epgstation = final.epgstation-h;
        })
    ]);
  };
}
