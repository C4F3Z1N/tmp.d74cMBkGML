{ coreutils, fetchgit, gawk, gitMinimal, lib, runCommandNoCC, yq-go, ... }:
let
  sources = runCommandNoCC "sources.json" {
    buildInputs = [ coreutils gitMinimal gawk yq-go ];
  } ''
    cp -r ${./.} src
    chmod 0755 src
    cd src

    git config -f .gitmodules --list | yq -M -o json -p props > gitmodules.json
    yq -e '.submodule | map(has("nix-hash")) | all' gitmodules.json &> /dev/null
    touch $out

    for each in $(yq -I 0 -M '.submodule | .[]' gitmodules.json); do
      name=$(yq -n "$each | .path")
      rev=$(git submodule status $name | awk '{gsub(/^-/, "", $1); print $1}')
      yq -i ".$name.url = ($each | .url)" $out
      yq -i ".$name.hash = ($each | .nix-hash)" $out
      yq -i ".$name.rev = \"$rev\"" $out
    done
  '';

  fetchers =
    builtins.mapAttrs (_: value: fetchgit (value // { name = "source"; }))
    (lib.importJSON sources);
in runCommandNoCC "nix-sources" { buildInputs = [ coreutils ]; }
(lib.concatLines ([ "mkdir -pv $out" ] ++ lib.mapAttrsToList
  (name: { outPath, ... }: "ln -fsv ${outPath} $out/${name}") fetchers))
