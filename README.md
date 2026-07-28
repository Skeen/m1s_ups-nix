# m1s_ups-nix

Nix flake packaging and a NixOS module for the ODROID M1S_UPS control service.

The UPS control script itself lives in a separate repo,
[`Skeen/m1s_ups`](https://github.com/Skeen/m1s_ups), and is consumed here as a
`flake = false` input (pinned in `flake.lock`).

## Usage

Add this flake as an input and import the module:

```nix
{
  inputs.m1s-ups-nix.url = "github:Skeen/m1s_ups-nix";

  outputs = { nixpkgs, m1s-ups-nix, ... }: {
    nixosConfigurations.m1s = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        m1s-ups-nix.nixosModules.default
        { services.m1s-ups.enable = true; }
      ];
    };
  };
}
```

Importing `nixosModules.default` applies an overlay (so `pkgs.m1s-ups` is
available) and enables the service wiring.

## Options (`services.m1s-ups.*`)

| Option | Default | Description |
| --- | --- | --- |
| `enable` | `false` | Enable the monitoring service. |
| `powerOffBatteryLevel` | `3550` | mV below which the board powers off while discharging (`4300` = power off on any discharge). |
| `powerOnBatteryLevel` | `0` | mV required before the UPS powers the board back on (`0` = on charge detect). |
| `watchdogResetTime` | `null` | Hardware watchdog reset time in seconds (1-9), or `null` to disable. Must exceed the ~4-5s loop time. |
| `logFile` | `null` | Battery log file path, or `null` to disable. |
| `package` | `pkgs.m1s-ups` | The package providing the control script. |

The module also installs a udev rule creating a stable `/dev/ttyM1S_UPS`
symlink for the UPS (VID:PID `1209:c550`) and binds the service to that device.

## Updating the script

```sh
nix flake update m1s-ups-script   # re-pin to the latest Skeen/m1s_ups commit
```
