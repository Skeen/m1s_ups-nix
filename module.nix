{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.m1s-ups;
in
{
  options.services.m1s-ups = {
    enable = lib.mkEnableOption "the ODROID M1S_UPS monitoring service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.m1s-ups;
      defaultText = lib.literalExpression "pkgs.m1s-ups";
      description = ''
        The m1s-ups package providing the control script. Defaults to the one
        supplied by this flake's overlay (applied by `nixosModules.default`).
      '';
    };

    powerOffBatteryLevel = lib.mkOption {
      type = lib.types.int;
      default = 3550;
      example = 3650;
      description = ''
        Battery voltage in mV below which the board is powered off while
        discharging. Use 4300 to power off as soon as a discharge condition is
        detected (vendor `BATTERY_LEVEL_FULL`). Maps to
        `CONFIG_POWEROFF_BATTERY_LEVEL`.
      '';
    };

    powerOnBatteryLevel = lib.mkOption {
      type = lib.types.int;
      default = 0;
      example = 3650;
      description = ''
        Battery voltage in mV that must be reached before the UPS powers the
        board back on after an outage. 0 means power on as soon as a charge
        condition is detected (the default). Maps to
        `CONFIG_POWERON_BATTERY_LEVEL`.
      '';
    };

    watchdogResetTime = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 1 9);
      default = null;
      example = 9;
      description = ''
        Hardware watchdog reset time in seconds (1-9), or null to disable.

        The value MUST be greater than the script's per-iteration run time
        (~4-5s), otherwise the board will reboot continuously. Maps to
        `CONFIG_WATCHDOG_RESET_TIME`.
      '';
    };

    logFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/var/log/ttyUPS.log";
      description = ''
        Path to a battery log file, or null to disable logging. Maps to
        `UPS_TTY_LOG`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.m1s-ups = {
      description = "Check the M1S_UPS status";
      wantedBy = [ "multi-user.target" ];
      # Order after (and require) the UPS device: prevents the race where the
      # service starts before udev has created /dev/ttyM1S_UPS, and stops the
      # service if the UPS is unplugged. Requires the udev rule's TAG+="systemd".
      after = [
        "syslog.target"
        "dev-ttyM1S_UPS.device"
      ];
      bindsTo = [ "dev-ttyM1S_UPS.device" ];

      environment = {
        # Point the script straight at the stable udev symlink instead of having
        # it scan sysfs for the VID/PID.
        M1S_UPS_NODE = "/dev/ttyM1S_UPS";
        M1S_UPS_POWEROFF_LEVEL = toString cfg.powerOffBatteryLevel;
        M1S_UPS_POWERON_LEVEL = toString cfg.powerOnBatteryLevel;
      }
      // lib.optionalAttrs (cfg.watchdogResetTime != null) {
        M1S_UPS_WATCHDOG_TIME = toString cfg.watchdogResetTime;
      }
      // lib.optionalAttrs (cfg.logFile != null) {
        M1S_UPS_LOG = toString cfg.logFile;
      };

      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Stable /dev/ttyM1S_UPS symlink for the CH55x UPS (VID:PID 1209:c550).
    # TAG+="systemd" makes systemd track the node as dev-ttyM1S_UPS.device, which
    # the service's after=/bindsTo= depend on. MODE/GROUP keep the default perms.
    services.udev.extraRules = ''
      SUBSYSTEM=="tty", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="c550", MODE="0660", GROUP="dialout", SYMLINK+="ttyM1S_UPS", TAG+="systemd"
    '';
  };
}
