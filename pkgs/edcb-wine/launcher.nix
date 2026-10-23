{
  lib,
  stdenv,
  writeShellScript,
  writeText,
  python3,
  wine,
  fontconfig,
  noto-fonts-cjk-sans,
  glibcLocales,
  tzdata,
  coreutils,
}:
let
  fonts = writeText "edcb-desktop-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">${fontconfig.out}/etc/fonts/fonts.conf</include>
      <dir>${noto-fonts-cjk-sans}/share/fonts</dir>
      <alias><family>MS Gothic</family><prefer><family>Noto Sans CJK JP</family></prefer></alias>
      <alias><family>MS PGothic</family><prefer><family>Noto Sans CJK JP</family></prefer></alias>
      <alias><family>MS UI Gothic</family><prefer><family>Noto Sans CJK JP</family></prefer></alias>
    </fontconfig>
  '';
in
writeShellScript "edcb-wine" ''
  set -euo pipefail
  ${lib.optionalString stdenv.hostPlatform.isLinux ''
    export LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
  ''}
  export TZDIR=${tzdata}/share/zoneinfo
  program="$(${coreutils}/bin/readlink -f "$0")"
  exec ${python3}/bin/python ${./run.py} \
    --bundle "''${program%/bin/edcb-wine}" \
    --wine-bin ${wine}/bin \
    --font ${noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc \
    --fontconfig ${fonts} \
    --initializer ${../../modules/edcb-wine/init-runtime.py} "$@"
''
