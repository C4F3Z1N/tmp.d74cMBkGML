json_modules := ```
    git config -f .gitmodules --list | \
        yq -M -o json -p props '
            .submodule |
            to_entries |
            map({"key": .value.path, "value": .value | del(.path)}) |
            from_entries
        '
```

alias unmount := umount

list:
    yq -n -o json -r '{{json_modules}} | keys | .[]'

show +modules=`just list`:
    for each in `printf '{{modules}}' | yq -I 0 -M -o json 'split(" ") as $m | {{json_modules}} | pick($m) | to_entries | .[]'`; do \
        key=$(yq -n "$each | .key"); \
        rev=$(git submodule status $key | awk '{gsub(/^-/, "", $1); print $1}'); \
        yq -M -n -o yaml ".$key = (($each | .value) *n {\"rev\":\"$rev\"})"; \
    done | yq -M -o json

build *nix-build-args:
    if `just show | yq -e 'map(has("nix-hash")) | all' &> /dev/null`; then \
        nix-build -E '(import <nixpkgs> {}).callPackage ./. {}' {{nix-build-args}}; \
    else \
        ! printf "nix-hash missing. run 'just lock' first." 1>&2; \
    fi

lock +modules=`just list`:
    for each in `just show '{{modules}}' | yq -I 0 -M -o json 'to_entries | .[]'`; do \
        key=$(yq -n "$each | .key"); \
        url=$(yq -n "$each | .value.url"); \
        rev=$(yq -n "$each | .value.rev"); \
        hash=$(nix-prefetch-git $url $rev | yq '.hash'); \
        git config -f .gitmodules --comment "custom field added by nix-source;" submodule.$key.nix-hash $hash; \
    done

mount +modules=`just list`:
    result=$(if [ -L ./result ] && [ -d ./result ]; then realpath ./result; else just build --no-out-link; fi); \
    for each in `printf '{{modules}}'`; do bindfs -r {{join("$result", "$each")}} $each; done

umount +modules=`just list`:
    for each in `printf '{{modules}}'`; do umount $each; done
