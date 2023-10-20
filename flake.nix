{
  description = "Libretech NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    flake-parts,
    nixos-generators,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} (let

      missingOverlay = final: super: {
        makeModulesClosure = x:
          super.makeModulesClosure (x // {allowMissing = true;});
      };
    
      osConfig = libretech-kernel: {
        config,
        pkgs,
        lib,
        ...
      }: {
          boot.kernelPackages = pkgs.linuxPackagesFor libretech-kernel;
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          nixpkgs.overlays = [missingOverlay];
      };
    in { moduleWithSystem, ... }: {
      systems = ["aarch64-linux"];
      flake.nixosModules.default = moduleWithSystem (
        perSystem@{ config }: 
        (osConfig config.packages.kernel)
      );
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: let
        libretech-kernel = pkgs.buildLinux {
          version = "6.1.y-lc";
          modDirVersion = "6.1.54";
          enableParallelBuilding = true;
          passthru.enableParallelBuilding = true;
          src = pkgs.fetchFromGitHub {
            owner = "libre-computer-project";
            repo = "libretech-linux";
            rev = "2cfb537893c212efade8fec2a2c088e8792ab6d5";
            sha256 = "sha256-5KhyUBUC1LyP8xpftJRvdETUViEe+Yg6RGmYhi6mrgI=";
          };
          extraMeta = {
            branch = "6.1.y-lc";
            platforms = ["aarch64-linux"];
          };
          kernelPatches = [];
          defconfig = "defconfig";
        };
      in {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [missingOverlay];
        };

        packages.kernel = libretech-kernel;
        packages.default = nixos-generators.nixosGenerate {
          modules = [
            (osConfig libretech-kernel)
          ];

          system = "aarch64-linux";
          format = "install-iso";

          inherit pkgs;
          lib = pkgs.lib;
        };
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [nil alejandra git gitg] ++ packages.default.buildInputs ++ packages.default.nativeBuildInputs ++ packages.default.propagatedBuildInputs;
        };
        formatter = pkgs.alejandra;
      };
    });
}
