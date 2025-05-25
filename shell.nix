let
  config = { overlays = [ (import ./overlay.nix) ]; };

  pkgs =
    if builtins.pathExists ./nixpkgs && builtins.readDir ./nixpkgs != { } then
      import ./nixpkgs config
    else
      import <nixpkgs> config;
in pkgs.mkShellNoCC {
  buildInputs = with pkgs; [ bindfs just nix-prefetch-git nix-sources yq-go ];
}
