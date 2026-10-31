# javadoc.rapidcow.org

Source for the static site at <https://javadoc.rapidcow.org>.

## Building

Perl is only a *build* dependency. The generated site is plain static
files, so serving it requires nothing beyond a web server.

You need Perl with `Template` (Template Toolkit), `URI` and the
`www-siteconf` distribution (`siteconf`, and `RdKw::WwW::GenLib`).

On Debian/Ubuntu, for the first two:

```sh
apt-get install libtemplate-perl liburi-perl
```

Then:

```sh
./configure
siteconf -g
make
```

The pages in `html/` are rendered into `site/`, which you can serve with
any static file server.

`./configure` accepts a few options (see `./configure -h`):

| Option | Meaning | Default |
| --- | --- | --- |
| `-Da=DIR` | Source directory | `html` |
| `-Db=DIR` | Target directory | `site` |
| `-DB=DIR` | Build directory (`MY/`, `Makefile`) | `.` |
| `-Osite_url=URL` | Absolute base | `https://javadoc.rapidcow.org` |
| `-Odata=DIR` | Data directory | `data` |

## Deploying to GitHub Pages

`docs/` is the published tree. It holds the javadoc itself (committed),
`CNAME`, and `.nojekyll`; the rest (everything listed in `MANIFEST`) is
generated into it and not tracked.

Pushing to `gh-pages` runs `.github/workflows/pages.yml`, which does:

```sh
./configure -Db=docs
siteconf -g
make
find docs -name .ok -delete
```

and publishes `docs/`. The repository's Pages source must be set to
"GitHub Actions" (Settings, Pages).

To preview locally, run the same commands and serve `docs/` with any
static file server (`./view` does this).

## About `configure`

`configure` is `siteconf -i -P web` plus local changes, kept as a patch
in `configure.patch` so that it can be regenerated:

```sh
siteconf -i -P web && patch configure < configure.patch
```

The goals of the build are in `MANIFEST`; `make` builds `site`, the only
one so far.
