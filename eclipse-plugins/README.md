# Eclipse plugin drop-in folder

Drop plugin bundles in this directory and rebuild the image; each one is
installed into the container's Eclipse (`/opt/eclipse`) at build time by
`scripts/51-install-eclipse-bundles.sh`, with no network access needed.

A bundle is a pair of files:

- `<name>.zip` — a mirrored p2 update site (the plugin and all its
  dependencies), repository at the zip root;
- `<name>.ius` — the installable units to install, one per line
  (`#` starts a comment). Features end in `.feature.group`.

Create both with the `eclipse-offline-package` command shipped in the
image, from anywhere with network access:

```sh
eclipse-offline-package --site https://download.eclipse.org/egit/updates \
    --iu org.eclipse.egit.feature.group --name egit
mv egit.zip egit.ius eclipse-plugins/
```

A zip without its `.ius` sidecar fails the build — the repository alone
does not say what to install (it also contains dependencies).

The zips also work without this folder: Eclipse reads them directly via
*Help > Install New Software... > Add... > Archive...*, handy on an
air-gapped machine.

Note: git is a poor home for large binaries — for big plugin sets consider
git-lfs or attaching the zips to a release and fetching them in CI.

Nothing here besides this README? Then the build step is a no-op.
