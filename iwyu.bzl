"""Shorter entrypoint for Include What You Use (IWYU) aspect."""

load("//bazel/iwyu:iwyu.bzl", _iwyu_aspect = "iwyu_aspect")

iwyu_aspect = _iwyu_aspect
