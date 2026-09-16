{
  description = "Development environment configuration";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      ...
    }@inputs:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      pkgsForSystem =
        system: nixpkgsSource:
        import nixpkgsSource {
          inherit system;
          config.allowUnfree = true;
        };

      forEachSystem = f: nixpkgs.lib.genAttrs systems f;
    in
    {
      formatter = forEachSystem (s: nixpkgs.legacyPackages.${s}.nixfmt);

      packages = forEachSystem (s: {
        programs.nixvim.plugins.lint.lintersByFt = {
          javascript = [ "eslint" ];
          typescript = [ "eslint" ];
        };
      });

      devShells = forEachSystem (
        s:
        let
          pkgs = pkgsForSystem s nixpkgs;
        in
        with pkgs;
        {
          default = mkShell {
            packages = [
              nodejs_22
              pnpm
              typescript
              eslint
              prettier
            ];

            shellHook = ''
              export PATH="$PWD/node_modules/.bin/:$PATH"
            '';
          };
        }
      );
    };
}
