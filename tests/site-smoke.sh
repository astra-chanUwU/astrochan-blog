#!/bin/sh

set -eu

HUGO_BIN=${HUGO_BIN:-hugo}
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

"$HUGO_BIN" --destination "$BUILD_DIR" --quiet

assert_contains() {
  file=$1
  needle=$2
  message=$3

  if ! grep -Fq "$needle" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

assert_count_at_least() {
  file=$1
  needle=$2
  minimum=$3
  message=$4
  count=$(grep -Fo "$needle" "$file" | wc -l | tr -d ' ')

  if [ "$count" -lt "$minimum" ]; then
    printf 'FAIL: %s (found %s, expected at least %s)\n' "$message" "$count" "$minimum" >&2
    exit 1
  fi
}

assert_before() {
  file=$1
  first=$2
  second=$3
  message=$4
  first_line=$(grep -Fn "$first" "$file" | head -n 1 | cut -d: -f1)
  second_line=$(grep -Fn "$second" "$file" | head -n 1 | cut -d: -f1)

  if [ -z "$first_line" ] || [ -z "$second_line" ] || [ "$first_line" -ge "$second_line" ]; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

assert_contains "$BUILD_DIR/writing/index.html" 'class="entry-date"' 'writing index renders publication dates'
assert_contains "$BUILD_DIR/writing/index.html" 'class="demo-marker"' 'writing index identifies removable demo posts'
assert_contains "$BUILD_DIR/writing/why-small-tools-last/index.html" '<time datetime="2026-08-24"' 'article renders a machine-readable publication date'
assert_contains "$BUILD_DIR/writing/why-small-tools-last/index.html" 'class="demo-marker"' 'article carries its subtle demo marker'
assert_contains "$BUILD_DIR/writing/reading-a-log-file-slowly/index.html" '<pre' 'technical article renders a code block'
assert_contains "$BUILD_DIR/writing/reading-a-log-file-slowly/index.html" '<table>' 'technical article renders a table'
assert_contains "$BUILD_DIR/misc/a-note-on-digital-gardens/index.html" '<blockquote>' 'misc note renders a blockquote'
SERVICES_PAGE="$BUILD_DIR/services/index.html"
assert_contains "$SERVICES_PAGE" 'class="notice notice-note"' 'services page is visibly identified as a demo'
assert_contains "$SERVICES_PAGE" 'Demo page' 'services page labels its placeholder content'
assert_contains "$SERVICES_PAGE" 'Small websites that last' 'services page includes a sample website offering'
assert_contains "$SERVICES_PAGE" 'Code and systems review' 'services page includes a sample review offering'
assert_contains "$SERVICES_PAGE" 'Technical writing' 'services page includes a sample writing offering'
assert_contains "$SERVICES_PAGE" 'mailto:hello@example.com?subject=Hello%20Astrochan' 'services page provides a clearly labeled demo contact link'
assert_contains "$SERVICES_PAGE" 'href="/writing/why-small-tools-last/"' 'services page links to a technology essay'
assert_contains "$SERVICES_PAGE" 'href="/writing/a-cache-is-a-promise/"' 'services page links to another technology essay'
assert_before "$BUILD_DIR/index.html" 'href="/writing/"' 'href="/services/"' 'Services navigation follows Writing'
assert_before "$BUILD_DIR/index.html" 'href="/services/"' 'href="/misc/"' 'Services navigation precedes Misc'
COMPILER_DEMO="$BUILD_DIR/writing/from-syntax-tree-to-instruction-stream/index.html"
assert_contains "$COMPILER_DEMO" 'class="article-toc"' 'long-form demo renders an article table of contents'
assert_contains "$COMPILER_DEMO" 'href="#lowering-one-expression"' 'table of contents links to nested article headings'
assert_contains "$COMPILER_DEMO" 'id="lowering-one-expression"' 'nested article headings expose stable anchors'
assert_contains "$COMPILER_DEMO" 'class="notice notice-series"' 'long-form demo renders its series notice'
assert_before "$COMPILER_DEMO" 'class="notice notice-series"' 'class="article-toc"' 'series notice appears before the table of contents'
assert_contains "$COMPILER_DEMO" 'class="notice notice-note"' 'long-form demo renders its explanatory note'
assert_contains "$COMPILER_DEMO" 'class="demo-marker"' 'long-form article carries its subtle demo marker'
assert_contains "$COMPILER_DEMO" 'href="https://mitchellh.com/zig/astgen"' 'long-form demo credits its structural reference'
assert_count_at_least "$COMPILER_DEMO" '<pre' 5 'long-form demo renders enough code blocks to exercise technical content'
assert_count_at_least "$COMPILER_DEMO" 'class="code-copy"' 5 'every fenced code sample renders an accessible copy control'
assert_contains "$COMPILER_DEMO" 'data-copy-code' 'code copy controls expose the clipboard behavior hook'
assert_contains "$COMPILER_DEMO" 'aria-label="Copy code"' 'code copy controls have an accessible name'
assert_contains "$COMPILER_DEMO" 'class="k"' 'Zig code renders Chroma syntax token classes'
assert_contains "$COMPILER_DEMO" '<script defer' 'technical articles load the copy interaction script'
TYPESCRIPT_DEMO="$BUILD_DIR/writing/typescript-at-the-boundary/index.html"
assert_contains "$TYPESCRIPT_DEMO" 'class="demo-marker"' 'TypeScript article carries its subtle demo marker'
assert_contains "$TYPESCRIPT_DEMO" 'class="article-toc"' 'TypeScript article renders a table of contents'
assert_contains "$TYPESCRIPT_DEMO" 'href="#unknown-is-a-useful-speed-bump"' 'TypeScript article exposes navigable section anchors'
assert_contains "$TYPESCRIPT_DEMO" 'class="language-typescript"' 'TypeScript examples are identified for syntax highlighting'
assert_contains "$TYPESCRIPT_DEMO" 'class="language-javascript"' 'JavaScript examples are identified for syntax highlighting'
assert_count_at_least "$TYPESCRIPT_DEMO" '<pre' 10 'TypeScript demo provides varied technical code examples'
assert_count_at_least "$TYPESCRIPT_DEMO" 'class="code-copy"' 10 'TypeScript demo gives each code sample a copy control'
assert_contains "$BUILD_DIR/writing/index.html" '>TypeScript at the Boundary<' 'writing index includes the TypeScript demo'
assert_contains "$BUILD_DIR/index.html" '<aside class="site-sidebar">' 'site renders persistent sidebar navigation'
assert_contains "$BUILD_DIR/index.html" '<div class="site-frame">' 'site renders the measured two-column shell'
assert_contains "$BUILD_DIR/index.html" '<img class="site-avatar"' 'site renders the profile avatar in its sidebar identity'

if [ ! -s "$BUILD_DIR/images/profile-head.png" ]; then
  printf 'FAIL: cropped profile image is present in the built site\n' >&2
  exit 1
fi

if [ ! -s "$BUILD_DIR/fonts/AtkinsonHyperlegible-Regular.woff2" ]; then
  printf 'FAIL: locally hosted Atkinson Hyperlegible font is present in the built site\n' >&2
  exit 1
fi

printf 'PASS: rendered demo content and metadata behave as expected\n'
