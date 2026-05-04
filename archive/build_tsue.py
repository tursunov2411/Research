"""Deprecated TSUE draft generator.

This archive script previously generated a parallel TSUE-formatted report and
inserted random bibliography keys from a non-versioned `references_expanded.bib`.
That workflow is not submission-safe because random citations can imply source
support that has not been checked.

Use `report_main.tex` as the single source of truth. If a TSUE-specific format
is needed, build a deterministic formatter that consumes the validated main
manuscript and `references_cleaned.bib`.
"""

raise SystemExit(
    "archive/build_tsue.py is deprecated. Use report_main.tex as the source of truth."
)
