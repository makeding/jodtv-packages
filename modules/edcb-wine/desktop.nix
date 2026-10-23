{
  pkgs,
  stateDir,
  desktopWidth,
  quickLauncherWidth,
  toolbarMargin,
  traySize,
  trayGap,
  edcbWineSrc,
  ...
}:
let
  fontFallbackReg = pkgs.runCommand "edcb-wine-fonts-ja.reg" { } ''
    install -m 0644 ${edcbWineSrc}/fonts-ja.reg "$out"
    printf '%s\n' \
      "" \
      "[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]" \
      "\"Noto Sans CJK JP (TrueType)\"=\"NotoSansCJK-VF.ttc\"" \
      "\"Noto Sans Mono CJK JP (TrueType)\"=\"NotoSansCJK-VF.ttc\"" \
      "" \
      "[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes]" \
      "\"MS Shell Dlg\"=\"Noto Sans CJK JP\"" \
      "\"MS Shell Dlg 2\"=\"Noto Sans CJK JP\"" \
      "\"Tahoma\"=\"Noto Sans CJK JP\"" \
      "\"Yu Gothic\"=\"Noto Sans CJK JP\"" \
      "\"Yu Gothic UI\"=\"Noto Sans CJK JP\"" \
      "" \
      "[HKEY_CURRENT_USER\\Control Panel\\Desktop]" \
      "\"FontSmoothing\"=\"2\"" \
      "\"FontSmoothingType\"=dword:00000002" \
      "\"FontSmoothingGamma\"=dword:00000578" \
      "\"FontSmoothingOrientation\"=dword:00000001" \
      >> "$out"
  '';

  fontconfigFile = pkgs.writeText "edcb-wine-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <dir>${pkgs.noto-fonts}/share/fonts</dir>
      <dir>${pkgs.noto-fonts-cjk-sans}/share/fonts</dir>
      <dir>${pkgs.noto-fonts-cjk-serif}</dir>
      <dir>${pkgs.noto-fonts-color-emoji}/share/fonts</dir>
      <dir>${pkgs.liberation_ttf}/share/fonts</dir>
      <cachedir>${stateDir}/fontconfig-cache</cachedir>

      <alias><family>sans-serif</family><prefer><family>Noto Sans CJK JP</family><family>Noto Sans</family></prefer></alias>
      <alias><family>serif</family><prefer><family>Noto Serif CJK JP</family><family>Noto Sans CJK JP</family></prefer></alias>
      <alias><family>monospace</family><prefer><family>Noto Sans Mono CJK JP</family><family>Noto Sans Mono</family></prefer></alias>

      <alias><family>MS Gothic</family><prefer><family>Noto Sans CJK JP</family></prefer></alias>
      <alias><family>MS PGothic</family><prefer><family>Noto Sans CJK JP</family></prefer></alias>
      <alias><family>MS UI Gothic</family><prefer><family>Noto Sans CJK JP</family></prefer></alias>
      <alias><family>MS Mincho</family><prefer><family>Noto Serif CJK JP</family><family>Noto Sans CJK JP</family></prefer></alias>
      <alias><family>MS PMincho</family><prefer><family>Noto Serif CJK JP</family><family>Noto Sans CJK JP</family></prefer></alias>
      <alias><family>Meiryo</family><prefer><family>Noto Sans CJK JP</family></prefer></alias>
      <alias><family>Meiryo UI</family><prefer><family>Noto Sans CJK JP</family></prefer></alias>

      <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
        <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
      </match>
    </fontconfig>
  '';

  openboxConfig = pkgs.writeText "edcb-wine-openbox-rc.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <openbox_config xmlns="http://openbox.org/3.4/rc">
      <applications>
        <application name="explorer.exe" class="explorer.exe" title="EDCB Tray">
          <decor>no</decor>
          <layer>above</layer>
          <desktop>all</desktop>
          <skip_taskbar>yes</skip_taskbar>
          <skip_pager>yes</skip_pager>
        </application>
      </applications>
    </openbox_config>
  '';

  pinTrayScript = pkgs.writeShellScript "pin-edcb-wine-tray" ''
    set -Eeuo pipefail

    title_regex='explorer[.]exe[.]explorer[.]exe|Wine System Tray|winesystemtray|EpgTimerSrvNotify|EpgTimerSrv.*Notify|EDCB.*Notify|TimerSrvNotify'
    tray_title='EDCB Tray'
    tray_x=${toString (desktopWidth - toolbarMargin - traySize)}
    tray_y=${toString (toolbarMargin + 8)}
    tray_width=${toString traySize}
    tray_height=${toString traySize}
    explorer_x=8
    explorer_y=90

    list_windows() {
      ${pkgs.wmctrl}/bin/wmctrl -lx
    }

    matching_windows() {
      list_windows | ${pkgs.gawk}/bin/awk -v regex="$title_regex" '
        BEGIN { IGNORECASE = 1 }
        $0 ~ regex { print $1 }
      '
    }

    is_tray_sized_window() {
      geometry="$(${pkgs.xwininfo}/bin/xwininfo -id "$1" 2>/dev/null || true)"
      width="$(printf '%s\n' "$geometry" | ${pkgs.gawk}/bin/awk '/Width:/ { print $2; exit }')"
      height="$(printf '%s\n' "$geometry" | ${pkgs.gawk}/bin/awk '/Height:/ { print $2; exit }')"

      [ -n "$width" ] && [ -n "$height" ] || return 1
      [ "$width" -le 360 ] && [ "$height" -le 160 ]
    }

    is_already_redecorated() {
      ${pkgs.xprop}/bin/xprop -id "$1" EDCB_WINE_TRAY_PINNED 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -q '= 1'
    }

    is_already_placed() {
      ${pkgs.xprop}/bin/xprop -id "$1" EDCB_WINE_EXPLORER_PLACED 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -q '= 1'
    }

    compact_tray() {
      ${pkgs.xprop}/bin/xprop -id "$1" -remove WM_NORMAL_HINTS >/dev/null 2>&1 || true
      ${pkgs.wmctrl}/bin/wmctrl -i -r "$1" -e "0,$tray_x,$tray_y,$tray_width,$tray_height" >/dev/null 2>&1 || true
      ${pkgs.xdotool}/bin/xdotool windowmove "$1" "$tray_x" "$tray_y" windowsize "$1" "$tray_width" "$tray_height" >/dev/null 2>&1 || true
    }

    redecorate_once() {
      is_already_redecorated "$1" && return 0

      ${pkgs.xprop}/bin/xprop -id "$1" \
        -f _MOTIF_WM_HINTS 32c \
        -set _MOTIF_WM_HINTS '0x2, 0x0, 0x0, 0x0, 0x0' \
        >/dev/null 2>&1 || true
      ${pkgs.xprop}/bin/xprop -id "$1" \
        -f EDCB_WINE_TRAY_PINNED 32c \
        -set EDCB_WINE_TRAY_PINNED 1 \
        >/dev/null 2>&1 || true
      compact_tray "$1"
      ${pkgs.xdotool}/bin/xdotool windowunmap "$1" windowmap "$1" >/dev/null 2>&1 || true
      sleep 0.2
      compact_tray "$1"
    }

    place_explorer_once() {
      is_already_placed "$1" && return 0

      ${pkgs.wmctrl}/bin/wmctrl -i -r "$1" -e "0,$explorer_x,$explorer_y,-1,-1" >/dev/null 2>&1 || true
      ${pkgs.xprop}/bin/xprop -id "$1" \
        -f EDCB_WINE_EXPLORER_PLACED 32c \
        -set EDCB_WINE_EXPLORER_PLACED 1 \
        >/dev/null 2>&1 || true
    }

    pin_once() {
      found=1
      while IFS= read -r window_id; do
        [ -n "$window_id" ] || continue
        if ! is_tray_sized_window "$window_id"; then
          place_explorer_once "$window_id"
          continue
        fi
        ${pkgs.wmctrl}/bin/wmctrl -i -r "$window_id" -T "$tray_title" >/dev/null 2>&1 || true
        compact_tray "$window_id"
        redecorate_once "$window_id"
        ${pkgs.wmctrl}/bin/wmctrl -i -r "$window_id" -b add,above,sticky >/dev/null 2>&1 || true
        found=0
      done < <(matching_windows)
      return "$found"
    }

    pin_once || true

    ${pkgs.xprop}/bin/xprop -root -spy _NET_CLIENT_LIST 2>/dev/null | while IFS= read -r _event; do
      sleep 0.2
      pin_once || true
    done
  '';

  quickLauncherTk = pkgs.writeText "edcb-wine-quick-launcher.tcl" ''
    package require Tk

    wm title . "EDCB tools"
    wm overrideredirect . 1
    catch { wm attributes . -topmost 1 }

    . configure -background "#ececec" -borderwidth 1 -relief solid
    frame .bar -background "#ececec" -padx 4 -pady 4
    pack .bar -side top -fill both

    proc send_action {name} {
      puts stdout $name
      flush stdout
    }

    foreach item {
      {"EDCB Folder" folder}
      {"EpgDataCap" epgdatacap}
      {"EpgTimerSrv" startsrv}
    } {
      lassign $item label action
      button .bar.$action -text $label -command [list send_action $action] -padx 8 -pady 3
      pack .bar.$action -side left -padx 2
    }

    button .bar.hide -text "Hide 30s" -command { wm withdraw .; after 30000 { wm deiconify .; raise . } } -padx 8 -pady 3
    pack .bar.hide -side left -padx 2

    update idletasks
    set margin ${toString toolbarMargin}
    set left_reserved 72
    set target_width ${toString quickLauncherWidth}
    set tray_size ${toString traySize}
    set tray_gap ${toString trayGap}
    set x [expr {[winfo screenwidth .] - $target_width - $tray_gap - $tray_size - $margin}]
    if {$x < $left_reserved} {
      set x $left_reserved
    }
    wm geometry . ''${target_width}x[winfo reqheight .]+$x+$margin
  '';

in
{
  inherit
    fontFallbackReg
    fontconfigFile
    openboxConfig
    pinTrayScript
    quickLauncherTk
    ;
}
