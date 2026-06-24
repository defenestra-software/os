# SPDX-License-Identifier: GPL-3.0-or-later
# defenestraOS custom ujust recipes. Auto-loaded via the `import?` slot in the
# ublue-os justfile, so no edit to that file is needed.

# Build against Nix-installed libraries (adds the Nix profile to PKG_CONFIG_PATH)
enable-nix-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    # Opt-in pkg-config exposure for bash, fish, and zsh. Scoped to
    # PKG_CONFIG_PATH; prefer `nix develop` for real per-project isolation.
    mkdir -p "$HOME/.bashrc.d" "$HOME/.config/fish/conf.d"
    ln -sf /usr/share/defenestra/nix-dev-env.sh   "$HOME/.bashrc.d/defenestra-nix-dev.sh"
    ln -sf /usr/share/defenestra/nix-dev-env.fish "$HOME/.config/fish/conf.d/defenestra-nix-dev.fish"
    # zsh has no auto-sourced drop-in dir; add a guarded source line (zsh reads
    # POSIX sh fine). The marker keeps enable/disable idempotent.
    if command -v zsh >/dev/null 2>&1 && ! grep -qs 'defenestra-nix-dev' "$HOME/.zshrc" 2>/dev/null; then
        printf '# defenestra-nix-dev\n[ -f /usr/share/defenestra/nix-dev-env.sh ] && source /usr/share/defenestra/nix-dev-env.sh\n' >> "$HOME/.zshrc"
    fi
    echo "Enabled. Open a new terminal; pkg-config will see Nix-installed libraries."

# Undo enable-nix-dev (remove the Nix pkg-config integration from your shells)
disable-nix-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -f "$HOME/.bashrc.d/defenestra-nix-dev.sh" \
          "$HOME/.config/fish/conf.d/defenestra-nix-dev.fish"
    if [ -f "$HOME/.zshrc" ]; then
        sed -i '/# defenestra-nix-dev/,+1d' "$HOME/.zshrc"
    fi
    echo "Disabled. Open a new terminal to clear PKG_CONFIG_PATH."
