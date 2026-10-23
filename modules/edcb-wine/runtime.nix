args@{
  pkgs,
  lib,
  stateDir,
  edcbDir,
  homeDir,
  winePrefix,
  wine,
  display,
  desktopSize,
  bootstrapVersion,
  notoSansCjk,
  edcbTemplate,
  edcbWinDir,
  mirakcHost,
  mirakcPort,
  recordingDir,
  recordingInfoDir,
  vncPort,
  vncListenAddress,
  ...
}:
let
  inherit (import ./desktop.nix args)
    fontFallbackReg
    fontconfigFile
    openboxConfig
    pinTrayScript
    quickLauncherTk
    ;
  startScript = pkgs.writeShellScript "start-edcb-wine-systemd" ''
      set -Eeuo pipefail

      export HOME=${homeDir}
      export DISPLAY=${lib.escapeShellArg display}
      export WINEARCH=win64
      export WINEPREFIX=${winePrefix}
      export TZ=Asia/Tokyo
      export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
      export TZDIR=${pkgs.tzdata}/share/zoneinfo
      export LANG=en_US.UTF-8
      export LANGUAGE=en_US:en
    export LC_ALL=en_US.UTF-8
    export FONTCONFIG_FILE=${fontconfigFile}
    export WINEDLLOVERRIDES=''${WINEDLLOVERRIDES:-mscoree,mshtml=}
    export EDCB_WINE_QUICK_LAUNCHER=''${EDCB_WINE_QUICK_LAUNCHER:-1}
    export EDCB_WINE_PIN_TRAY=''${EDCB_WINE_PIN_TRAY:-1}

      marker="$WINEPREFIX/.edcb-wine-bootstrap-v${bootstrapVersion}"
      x_pid=""
      vnc_pid=""
      wm_pid=""
      launcher_pid=""
      tray_pin_pid=""
      edcb_pid=""

      cleanup() {
        for pid in "$launcher_pid" "$tray_pin_pid" "$wm_pid" "$vnc_pid"; do
          if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
            kill "$pid" >/dev/null 2>&1 || true
          fi
        done
        ${wine}/bin/wineserver -k >/dev/null 2>&1 || true
        if [ -n "$x_pid" ] && kill -0 "$x_pid" >/dev/null 2>&1; then
          kill "$x_pid" >/dev/null 2>&1 || true
        fi
      }

      shutdown() {
        trap - EXIT INT TERM
        cleanup
        exit 0
      }

      trap cleanup EXIT
      trap shutdown INT TERM

      wait_for_x() {
        for i in $(seq 1 30); do
          if ${pkgs.xset}/bin/xset -display "$DISPLAY" -q >/dev/null 2>&1; then
            return 0
          fi
          echo "Waiting for Xvfb on $DISPLAY... ($i/30)"
          sleep 1
        done
        echo "Xvfb did not become ready on $DISPLAY" >&2
        return 1
      }

      terminate_existing_wine() {
        echo "Stopping stale Wine processes for $WINEPREFIX..."
        ${wine}/bin/wineserver -k >/dev/null 2>&1 || true
        ${wine}/bin/wineserver -w >/dev/null 2>&1 || true
      }

      ensure_runtime_tree() {
        ${pkgs.python3}/bin/python ${./init-runtime.py} \
          ${edcbTemplate} ${lib.escapeShellArg stateDir} \
          ${lib.escapeShellArg recordingDir} ${lib.escapeShellArg recordingInfoDir} \
          ${lib.escapeShellArg mirakcHost} ${toString mirakcPort}
      }

      ensure_font_fallback() {
        ${pkgs.fontconfig}/bin/fc-cache -f -v || true

        if [ -d "$WINEPREFIX/drive_c/windows/Fonts" ]; then
          ln -sf ${notoSansCjk} "$WINEPREFIX/drive_c/windows/Fonts/NotoSansCJK-VF.ttc"
        fi

        if [ -f "$WINEPREFIX/system.reg" ] || [ -d "$WINEPREFIX/drive_c/windows" ]; then
          ${wine}/bin/regedit /S ${fontFallbackReg} || true
        fi
      }

      ensure_wineprefix() {
        if [ -f "$marker" ]; then
          ensure_font_fallback
          return 0
        fi

        echo "Bootstrapping Wine prefix at $WINEPREFIX..."
        ${wine}/bin/wineboot --init
        ${wine}/bin/wineserver -w

        ensure_font_fallback
        ${wine}/bin/wineboot -u
        ${wine}/bin/wineserver -w

        mkdir -p "$WINEPREFIX/dosdevices"
        rm -f "$WINEPREFIX/dosdevices/d:"
        ln -s /mnt "$WINEPREFIX/dosdevices/d:"

        touch "$marker"
        echo "Wine prefix bootstrap completed."
      }

      open_edcb_folder() {
        ${wine}/bin/wine explorer.exe /e,"${edcbWinDir}" &
      }

      open_epgdatacap_bon() {
        (
          cd ${edcbDir}
          ${wine}/bin/wine start /unix ${edcbDir}/EpgDataCap_Bon.exe
        ) &
      }

      launch_edcb() {
        if [ -n "$edcb_pid" ] && kill -0 "$edcb_pid" >/dev/null 2>&1; then return 0; fi
        cd ${edcbDir}
        ${wine}/bin/wine ${edcbDir}/EpgTimerSrv.exe &
        edcb_pid="$!"
      }

      start_quick_launcher() {
        (
          trap 'exit 0' INT TERM EXIT

          while kill -0 "$x_pid" >/dev/null 2>&1; do
            set +e
            ${pkgs.tk}/bin/wish ${quickLauncherTk} | while IFS= read -r action; do
              case "$action" in
                folder)
                  open_edcb_folder || true
                  ;;
                epgdatacap)
                  open_epgdatacap_bon || true
                  ;;
                startsrv)
                  launch_edcb || true
                  ;;
              esac
            done
            set -e
            sleep 2
          done
        ) &
        launcher_pid="$!"
      }

      start_tray_pinner() {
        ${pinTrayScript} &
        tray_pin_pid="$!"
      }

      install_desktop_launchers() {
        mkdir -p "$WINEPREFIX/drive_c/users/edcb-wine/Desktop" "$WINEPREFIX/drive_c/users/Public/Desktop"
        for desktop_dir in "$WINEPREFIX"/drive_c/users/*/Desktop; do
          [ -d "$desktop_dir" ] || continue
          cp ${edcbDir}/Open_EDCB_Folder.bat "$desktop_dir/Open EDCB Folder.bat"
          cp ${edcbDir}/Open_EpgDataCap_Bon.bat "$desktop_dir/Open EpgDataCap Bon.bat"
          cp ${edcbDir}/ChannelScan_mirakc_T.bat "$desktop_dir/Channel Scan mirakc T.bat"
          cp ${edcbDir}/ChannelScan_mirakc_S.bat "$desktop_dir/Channel Scan mirakc S.bat"
          chmod u+rw "$desktop_dir/"*.bat
        done
      }

      terminate_existing_wine
      ensure_runtime_tree

      echo "Starting Xvfb on $DISPLAY..."
      ${pkgs.xorg-server}/bin/Xvfb "$DISPLAY" -screen 0 ${desktopSize}x24 -ac +extension GLX +render -noreset &
      x_pid="$!"
      wait_for_x

      echo "Starting openbox window manager..."
      ${pkgs.openbox}/bin/openbox --config-file ${openboxConfig} &
      wm_pid="$!"
      sleep 1

      echo "Starting x11vnc on port ${toString vncPort}..."
      ${pkgs.x11vnc}/bin/x11vnc -display "$DISPLAY" -forever -shared -listen ${lib.escapeShellArg vncListenAddress} -rfbport ${toString vncPort} -nopw -noxrecord -noxdamage -repeat &
      vnc_pid="$!"

    ensure_wineprefix
    mkdir -p "$WINEPREFIX/dosdevices"
    ln -sfn /mnt "$WINEPREFIX/dosdevices/d:"
    install_desktop_launchers

    if [ "$EDCB_WINE_QUICK_LAUNCHER" = "1" ]; then
      echo "Starting EDCB quick launcher..."
      start_quick_launcher
    fi

    if [ "$EDCB_WINE_PIN_TRAY" = "1" ]; then
      echo "Starting EDCB tray window pinner..."
      start_tray_pinner
    fi

    echo "Starting EDCB EpgTimerSrv..."
    launch_edcb

    while { kill -0 "$x_pid" && kill -0 "$edcb_pid" && kill -0 "$vnc_pid" && kill -0 "$wm_pid"; } >/dev/null 2>&1; do
      sleep 5
    done
  '';
in
startScript
