{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  coreutils,
  gnugrep,
  gnused,
  gawk,
  findutils,
  procps,
  systemd,
  src,
}:

# Packages the M1S_UPS control script (check_ups.sh) as a self-contained,
# wrapped executable. The script itself lives in its own repository
# (github:Skeen/m1s_ups) and is passed in as `src`; its knobs are driven by
# $M1S_UPS_* environment variables, which the NixOS module wires up to systemd.

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "m1s-ups";
  version = "0-6"; # targets UPS firmware V0-6; script itself is unversioned

  inherit src;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  # All external commands the script shells out to at runtime.
  runtimeInputs = [
    coreutils # cat, cut, date, echo, printf, sleep, stty, kill
    gnugrep # grep
    gnused # sed
    gawk # awk
    findutils # find, xargs
    procps # ps
    systemd # poweroff
  ];

  installPhase = ''
    runHook preInstall

    install -Dm0644 "$src/check_ups.sh" "$out/libexec/m1s-ups/check_ups.sh"

    makeWrapper ${lib.getExe bash} "$out/bin/m1s-ups" \
      --add-flags "$out/libexec/m1s-ups/check_ups.sh" \
      --prefix PATH : ${lib.makeBinPath finalAttrs.runtimeInputs}

    runHook postInstall
  '';

  meta = {
    description = "ODROID M1S_UPS control/monitoring service (check_ups.sh)";
    homepage = "https://github.com/Skeen/m1s_ups";
    # Script is derived from the ODROID wiki, licensed CC Attribution-Share Alike 4.0.
    license = lib.licenses.cc-by-sa-40;
    mainProgram = "m1s-ups";
    platforms = lib.platforms.linux;
  };
})
