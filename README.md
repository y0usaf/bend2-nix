# bend2-nix

A Nix flake for **Bend 2** -- [`bendlang/bend`](https://github.com/bendlang/bend),
the TypeScript implementation run on [bun](https://bun.sh) -- the release named at
<https://bend-lang.com/dl/latest.json>.

This is **not** the OLD Rust `HigherOrderCO/Bend` (`pkgs/by-name/be/bend` in
nixpkgs, 0.2.37). Different project, different language, same name.

## Pin

| | |
|---|---|
| version | `2.0.5` |
| url | `https://bend-lang.com/dl/2.0.5.tar.gz` |
| sha256 | `4db70e77ce1b1027f1d0e15dee025921fa794a9b415add4350ec7c64acf2775b` |

Bumped by `./update.sh`, which reads `latest.json` (the same manifest the official
installer trusts) and rewrites the version and hash. `nix` verifies the hash on
fetch, and the tarball in the store re-hashes to the published value:

```
$ nix store cat $(nix eval --raw .#bend.src.outPath) | sha256sum
4db70e77ce1b1027f1d0e15dee025921fa794a9b415add4350ec7c64acf2775b  -
```

## Use

```sh
nix build            # packages.<system>.default == packages.<system>.bend
nix run . -- --version
nix develop          # bun + clang, for working on Bend source
```

## What the wrapper does

Upstream's launcher (read from `install.sh`) ends in one exec:

```sh
"$BUN" "$B/current/bend2/main.ts" "$@"
```

with `B=${BEND_HOME:-$HOME/.bend}`. Everything before that line is install /
self-update / telemetry bookkeeping; none of it is part of running Bend. This
flake ships the release and a small wrapper (via `makeWrapper`) that reproduces
the exec and the environment the launcher relies on, and nothing else:

- runs `bun <out>/share/bend/bend2/main.ts "$@"`;
- `BEND_HOME=<out>/share/bend`, laid out as an install the launcher would
  recognise (`current -> .`, so `$BEND_HOME/current/bend2/main.ts` exists);
- `BEND_NO_TELEMETRY=1` -- with an installed tree and this set, the launcher sends
  no ping and never updates;
- `unset CC` -- `main.ts` `cc_find` uses `$CC` verbatim if it is set, and rejects a
  gcc `$CC` outright; unset, it searches PATH for `clang` / `clang-NN`;
- `clang` (nixpkgs `clang-wrapper`, 21.x -- above the `>= 14` CPU build needs) and
  `bun` prepended to PATH, so `bend <prog>.bend -o <out>` works from the packaged
  CLI with no gcc on PATH.

Plain runs make no network calls: `main.ts` only fetches in the `--publish` path.

## Verification (real runs)

Quoted as run. Pin: store path
`/nix/store/wjmg4b75jbrq1lnrfsp0k3s8fbdl3qp5-bend-2.0.5`.
Checkout for inputs: `/home/y0usaf/dev/sandbox/bend-review-20260917/repo/bend`.

1. **Build exits zero.**

   ```
   $ nix build ; echo $?
   0
   $ readlink -f result
   /nix/store/wjmg4b75jbrq1lnrfsp0k3s8fbdl3qp5-bend-2.0.5
   ```

2. **Built artifact on real Bend files.**

   ```
   $ ./result/bin/bend demos/io_hello_world/main.bend
   Hello, world!                                    # exit 0

   $ ./result/bin/bend demos/pure_par_sum/main.bend
   2147450880                                       # exit 0, as its header says

   $ ./result/bin/bend demos/proof_insertion_sort/PROOF.bend
   All terms check.                                 # exit 0
   ```

3. **Native build through the packaged CLI.**

   ```
   $ ./result/bin/bend /tmp/hello.bend -o /tmp/out
   $ ls -l /tmp/out
   -rwxr-xr-x 40568 /tmp/out                         # real ELF, via clang on PATH
   $ /tmp/out
   524288                                            # exit 0
   ```

4. **Hermetic / offline.** Empty `HOME`, no network namespace at all, and the
   launcher origin pointed at a dead address:

   ```
   $ H=$(mktemp -d)
   $ unshare -rn env HOME=$H BEND_ORIGIN=http://127.0.0.1:1 \
       ./result/bin/bend .../demos/io_hello_world/main.bend
   Hello, world!                                     # exit 0
   $ find "$H" -mindepth 1 | wc -l
   0                                                 # nothing written to $HOME
   ```

   The real `~/.bend` (a pre-existing curl install) was unchanged: 84 entries and
   identical mtimes before and after. Nothing self-updates or phones home.

5. **Reproducible.**

   ```
   $ nix build ; readlink -f result
   /nix/store/wjmg4b75jbrq1lnrfsp0k3s8fbdl3qp5-bend-2.0.5
   $ nix build --rebuild ; readlink -f result
   /nix/store/wjmg4b75jbrq1lnrfsp0k3s8fbdl3qp5-bend-2.0.5   # identical
   ```

## Known limits

- Verified on `x86_64-linux` only. The other systems are exposed but untested
  here; macOS needs Xcode's clang for native builds upstream.
- GPU builds (`sum!` on device) need clang 19+ / Metal / CUDA 12. nixpkgs clang is
  21, so CPU and Linux-native builds work; GPU was not exercised.
- `bend guide` reads `<root>/guide/GUIDE.md`, which the release tarball ships; the
  flake copies the tarball verbatim, so any upstream omission is reproduced
  faithfully rather than patched.
- nixpkgs is pinned to a `nixos-unstable` snapshot (see `flake.lock`), not a
  release; refresh with `nix flake update`.

## Alternative rejected

Building from a git checkout of `bendlang/bend` (or `buildBunPackage`/bun2nix).
Rejected because upstream's only install mechanism is the release tarball plus its
published sha256: fetched by URL with that hash, the flake is byte-identical to
what `install.sh` installs and stays verifiable against `latest.json`. A source
build would need a second, unrelated pin and would drift from the installer.
