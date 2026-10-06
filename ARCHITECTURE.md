# ARCHITECTURE.md

The architecture document for this repository, following the
[architecture.md](https://architecture.md) schema — built so an agent (or a
new colleague) can comprehend the repository from this file alone. This is a
Nix devshell flake: a small, versioned development environment consumed as a
git submodule. Fill every section; update it in the same change that alters
the architecture it describes.

## 1. Project Structure

Flat by design — one flake, its lock, and the docs.

```
devshell-node/
├── flake.nix          # inputs + devShells.default + formatter
├── flake.lock         # pinned nixpkgs / nixvim revisions
├── README.md          # how to consume (submodule + .envrc)
├── CHANGELOG.md       # release-generated
├── .vale.ini          # prose linting (proselint, alex) for markdown
├── .editorconfig
└── .github/workflows/changelog.yaml
```

**Where the logic lives.** The environment is the `devShells.default`
definition in `flake.nix`: the package list, the `shellHook`, and the
`nixConfig` substituters. There is no application code; the flake is the
single source of truth for the toolchain versions.

## 2. High-Level System Diagram

```
  consumer repo                              devshell-node (this repo)
  ┌──────────────────────┐                   ┌───────────────────────────┐
  │ .envrc:              │   git submodule   │ flake.nix                 │
  │   use flake ./devshell│ ────────────────► │  inputs: nixpkgs, nixvim  │
  │ devshell/ (submodule)│                   │  devShells.default:       │
  └──────────┬───────────┘                   │   nodejs_22, pnpm,        │
             │ direnv allow                   │   typescript, eslint,     │
             ▼                                │   prettier + shellHook    │
  ┌──────────────────────┐                   └───────────────────────────┘
  │ nix develop shell     │◄──── substituters: cache.nixos.org,
  │ (node, pnpm on PATH)  │       nix-community.cachix.org
  └──────────────────────┘
```

## 3. Core Components

| Component | Responsibility |
|---|---|
| `devShells.default` | The environment: `nodejs_22`, `pnpm`, `typescript`, `eslint`, `prettier`; `shellHook` prepends `$PWD/node_modules/.bin` to `PATH` |
| `formatter` | `nixfmt` for the repo |
| `packages.programs.nixvim.plugins.lint.lintersByFt` | nixvim lint wiring for JS/TS (`eslint`) |
| `inputs.nixpkgs`, `inputs.nixvim` | Pinned sources (`nixpkgs` follows into `nixvim`) |
| `nixConfig` | Extra substituters and their trusted public keys |

### Ports & adapters

Not applicable. This repo owns no ports or adapters; it defines a development
environment. Its "interface" is the flake output (`devShells.default`) and the
consumption contract in §12.

## 4. Data Stores

None. The Nix store holds the pinned package closures; `flake.lock` pins the
input revisions. No database or persistent state.

## 5. External Integrations / APIs

- **nixpkgs / nixvim** — flake inputs from GitHub, pinned in `flake.lock`.
- **Binary caches** — `https://cache.nixos.org` and
  `https://nix-community.cachix.org`, declared with trusted public keys in
  `nixConfig`.
- No runtime APIs.

## 6. Deployment & Infrastructure

- **Consumption**: added to a project as a git submodule at `./devshell`,
  then activated through `.envrc` → `use flake ./devshell` and
  `direnv allow`.
- **Versioning**: changes are managed centrally here; if different versions
  must be maintained, they live on separate branches (per `README.md`).
- **CI/CD**: a `changelog.yaml` workflow generates the changelog on push to
  `main`.
- **Monitoring/logging**: none.

## 7. Security Considerations

- **Substituters**: extra binary caches are pinned by public key in
  `nixConfig`, so a substituted path must match a trusted signature.
- **Unfree packages**: `config.allowUnfree = true` is set for the imported
  nixpkgs.
- No secrets, tokens or credentials live in this repo.

## 8. Development & Testing Environment

- **Local setup**: `nix develop` (or enter via a consumer's `direnv allow`)
  provides the shell. `nix fmt` formats with `nixfmt`.
- **Testing**: none — the flake's correctness is its evaluation and a
  successful `nix develop`.
- **Code quality**: `nixfmt` via the flake `formatter`; `.vale.ini`
  configures prose linting (`proselint`, `alex`) for markdown.
- **Mechanical gates and what they make impossible**: pinning `flake.lock`
  makes an unreviewed input bump impossible (Dependabot/the changelog
  workflow surfaces the change); pinned substituter keys make an unsigned
  binary cache impossible.

## 9. Future Considerations / Roadmap

**Deliberate non-goals** (from `README.md`):

- **Not a production environment.** The devshell packages only what is
  needed to develop (install, test-watch, lint, format); everything else is
  abstracted into dedicated Docker containers so development matches
  production as closely as possible.
- **No `flake-utils`.** Keep the flake close to plain Nix; the `systems`
  list and `forEachSystem` are written by hand.
- **No per-project overrides in the flake.** A project that needs a different
  toolchain maintains a branch of this repo, not a fork of the flake.
- **No application code.** This repo defines an environment; it does not
  build or ship an application.

**Known debt / open items**: none recorded.

## 10. Project Identification

Project Name: devshell-node

Repository URL: https://github.com/99linesofcode/devshell-node

Primary Contact/Team: Jordy Schreuders (99linesofcode)

Date of Last Update: 2026-10-06

## 11. Glossary / Acronyms

- **Devshell** — a `nix develop` environment (here, the `devShells.default`
  output).
- **Flake** — a Nix project with a pinned `flake.lock` and an `outputs`
  function.
- **Submodule** — the git mechanism a consumer uses to pull this repo into
  `./devshell`.
- **direnv** — the tool that activates the flake on entering the directory
  (`use flake ./devshell`).
- **Substituter** — a binary cache; pinned by public key.
- **`mkShell`** — the nixpkgs helper that builds a devshell.
- **`nixConfig`** — flake-level Nix configuration (extra substituters and
  trusted keys).

## 12. Conventions & Boundaries

The consumption contract and the standards this repo enforces on itself.

- **Consumption contract** (a consumer must do exactly this):
  1. `git submodule add https://github.com/99linesofcode/devshell-node ./devshell`
  2. `echo use flake ./devshell >> .envrc`
  3. `direnv allow`
  4. add `.direnv/` to `.gitignore` (the shared rule already comes from
     git-skeleton)
- **One flake, one environment**: the toolchain versions are declared only in
  `flake.nix`; consumers do not pin their own node/pnpm versions outside it.
- **Versioning by branch**: maintain a divergent toolchain on a branch, not
  by parameterising the flake.
- **Pinning**: `flake.lock` is committed; inputs are bumped deliberately and
  the change is visible.
- **Formatting**: `nixfmt` via `nix fmt`; `.editorconfig` for the rest.
- **Documentation surfaces**: `README.md` carries the consumption recipe; a
  change to the shell or the contract updates this file in the same change.
