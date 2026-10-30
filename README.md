# javadoc.rapidcow.org

Source for the static site at <https://javadoc.rapidcow.org>.

## Building

Perl is only a *build* dependency. The generated site is plain static
files, so serving it requires nothing beyond a web server.

You need Perl with the following modules:

- `File::Which`
- `Template` (Template Toolkit)
- `URI`

On Debian/Ubuntu:

```sh
apt-get install libfile-which-perl libtemplate-perl liburi-perl
```

Then:

```sh
./configure
make
```

The pages in `html/` are rendered into `site/`, which you can serve with
any static file server.

`./configure` accepts a few options (see `./configure -h`):

| Option | Meaning | Default |
| --- | --- | --- |
| `-Da=DIR` | Source directory | `html` |
| `-Db=DIR` | Target directory | `site` |
| `-Dtar_from_stdin=CMD` | Implementation of `tar -T -`, as in GNU tar | autodetected |

## Deploying to GitHub Pages

The `docs/` directory is committed so that GitHub Pages can serve it
directly. To build into it:

```sh
./configure -Db=docs
make
```

Then commit the result.
