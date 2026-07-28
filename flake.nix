{
  description = "Nix packaging + NixOS module for the ODROID M1S_UPS control service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The (modified) UPS control script lives in its own repo. flake = false so
    # we consume the raw tree; the exact revision is pinned in flake.lock.
    m1s-ups-script = {
      url = "github:Skeen/m1s_ups";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      m1s-ups-script,
    }:
    let
      # The M1S is aarch64.
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        m1s-ups = pkgs.callPackage ./package.nix { src = m1s-ups-script; };
        default = self.packages.${system}.m1s-ups;
      };

      overlays.default = final: _prev: {
        m1s-ups = final.callPackage ./package.nix { src = m1s-ups-script; };
      };

      # Import this into your NixOS configuration, then set
      #   services.m1s-ups.enable = true;
      # It applies the overlay (so pkgs.m1s-ups exists) and pulls in the module.
      nixosModules.default =
        { ... }:
        {
          imports = [ ./module.nix ];
          nixpkgs.overlays = [ self.overlays.default ];
        };
      nixosModules.m1s-ups = self.nixosModules.default;

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
