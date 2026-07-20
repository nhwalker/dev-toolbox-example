# VS Code extension drop-in folder

Drop `.vsix` files in this directory and rebuild the image; each one is
installed into the container's VS Code at build time by
`scripts/50-install-vsix-extensions.sh`.

Extensions are unpacked into VS Code's built-in extensions directory
(`/usr/share/code/resources/app/extensions`), so they:

- are available to every user of the container, out of the box;
- do not touch `~/.vscode/extensions` (which Toolbx shares with the host);
- cannot be uninstalled from the VS Code UI — remove the `.vsix` here and
  rebuild instead.

Getting a `.vsix`:

- Open VSX: `https://open-vsx.org/api/<publisher>/<name>/<version>/file/<publisher>.<name>-<version>.vsix`
- VS Code Marketplace: "Download Extension" link on the extension's page.

Nothing here besides this README? Then the build step is a no-op.
