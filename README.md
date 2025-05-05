# Helix PDF

This repository contains scripts that make working with PDF previews more
convenient in Helix. Currently, only the Typst preview is provided.

## Zathura Typst Preview

### Installation

- Download the [hx-typ-zathura.fish](./hx-typ-zathura.fish) file.

### Dependencies

- Helix built from `master`.
- [fish](https://fishshell.com/)
  - Needs to be available, but it does _not_ need to be your selected shell.
- [fd](https://github.com/sharkdp/fd)
- [typst](https://github.com/typst/typst)
- [zathura](https://github.com/pwmt/zathura)
- `git`
- `waitpid`

### Usage

Assign the command to a keybinding in Helix. Take care to include the
`%{buffer_name}` command expansion. For example:

```toml
your_key = ':sh /path/to/hx-typ-zathura.fish --watch --kill-on-exit %{buffer_name}'
```

You can use this script to conveniently open a PDF preview to the Typst document
you are currently editing. It will do its best to find the PDF file that matches
your current buffer. It will check the current directory first, then it will
search recursively from the repository root. If you're not in a repository,
it'll recursively search from your working directory, instead.

Optionally, the Zathura window can be killed if you close Helix. There is also
an option to continuously update the preview using `typst watch`.

It takes the path to the typst file as its only argument, and the following
options are provided:

```
-q/--quiet: Don't echo back to Helix on caught errors, return 1 instead.
-k/--kill-on-exit: Kill Zathura and typst when Helix exits.
-w/--watch: Use typst watch to compile a live preview.
-h/--help: Print help screen.
```

To avoid spawning a large number of `typst watch` processes, the `--watch`
option _only_ works if `--kill-on-exit` is also set.
