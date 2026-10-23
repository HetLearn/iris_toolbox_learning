hetlearn technical appendix
===========================

Files
  technical_appendix.tex   the appendix: a standalone LaTeX article (sections, table of
                           contents, cross-references, option index in Appendix A)
  references.bib           its bibliography (BibTeX, natbib author-year, plainnat style)

Compile on Overleaf
  1. New project > Upload project: upload both files (or a zip of this folder).
  2. Menu > Compiler: pdfLaTeX. Main document: technical_appendix.tex.
  3. Recompile. Overleaf runs BibTeX by itself; if the references show as "?",
     recompile once more.

Compile locally (TeX Live or MiKTeX)
  pdflatex technical_appendix
  bibtex   technical_appendix
  pdflatex technical_appendix
  pdflatex technical_appendix
or, with latexmk:
  latexmk -pdf technical_appendix

Packages: fontenc, inputenc, lmodern, textcomp, geometry, amsmath, amssymb, booktabs,
array, longtable, enumitem, xcolor, listings, natbib, url, hyperref. All are in a standard
TeX Live or MiKTeX installation. No figures, no shell escape.

Editing notes
  - Inline code is written \code{...} (a url-package command). It prints its argument
    literally (underscores, braces, quotes) and can break at punctuation and spaces. The
    argument must not contain %, # or a backslash. Write \texttt{\%} for a percent sign.
  - In headings, inside \texorpdfstring and inside math, write \codem{...} instead: it
    prints the same but cannot break. In a section title, wrap it in \texorpdfstring, e.g.
    \subsubsection{\texorpdfstring{\codem{gain.value}}{gain.value}}.
  - Every option entry is an optspec environment with the fields Default, Values, Math,
    Assumptions, Interactions, Code, Example; the examples are lstlisting blocks of one or
    two lines.
  - Appendix A lists every option with its default; add a row there when an option is added.

Scope and status
  The appendix documents the core toolbox (two agent types: RE agents and learners) in
  toolbox/+hetlearn. It leaves out the bounded-rationality extensions (expectations.types,
  expectations.transforms, shares.init, shares.fixed) and the estimation module.
  Compiles with pdflatex and bibtex (TinyTeX, TeX Live 2026) with no errors, no undefined
  references and no overfull lines.
