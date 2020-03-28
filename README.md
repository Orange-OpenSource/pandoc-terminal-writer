# Pandoc Terminal Writer -- Pretty-print text documents on a terminal

## Presentation

This is a [custom writer](https://pandoc.org/lua-filters.html) (output driver)
for **pandoc** written in lua. When chosen as output format, it will
pretty-print the input document on the terminal. It makes heavy use of VT100
control sequences and Unicode box-drawing characters.

As Pandoc supports many input formats:

> (several dialects of) Markdown, reStructuredText, textile, HTML, DocBook,
> LaTeX, MediaWiki markup, TWiki markup, TikiWiki markup, Creole 1.0, Vimwiki
> markup, OPML, Emacs Org-Mode, Emacs Muse, txt2tags, Microsoft Word docx,
> LibreOffice ODT, EPUB, or Haddock markup.

this writer is suitable for displaying any document in any of these input
formats.

## Usage

You need to have [pandoc installed](https://pandoc.org/installing.html) on your machine,
and the **terminal.lua** script from this repository copied somewhere on your machine.

Then invoke the reader with

```bash
$ pandoc -t [path/to/]terminal.lua [the_document]

# e.g.:

$ pandoc -t terminal.lua README.md
```

As word wrapping is not yet supported, you may want to pipe the output into the
`fold` command. You may also want to use a _pager_ such as `less`:

```bash
$ pandoc -t terminal.lua README.md | fold -s | less -r
```

Note that currently the word wrapping as implemented by `fold` will break the
indentation and the code and quote blocks decorations. This is an issue we want
to address inside the writer in the near future.

This writer tries to adapt automatically the maximal width of some elements (like
_table_ or _blockquotes_). If you want to narrow those elements, you can export
the "`COLUMNS`" environment variable with the terminal width of you choice:

```bash
$ COLUMNS=80 pandoc -t terminal.lua README.md | less -r
```

## Demo

A screenshot is worth 1000 words:

This document :

![Current README.md](res/screenshot1.png)

Another Markdown document :

![the showcase.md test document](res/screenshot2.png)

A LibreOffice text document

![LibreOffice and terminal rendered document](res/screenshot3.png)

## Authors

© 2018 — 2020 Orange

Camille Oudot

Benoît Bailleux

## Licence

This work is published under the MIT license
