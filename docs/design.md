# Design direction

## Core idea

`astrochan-blog` is a personal technical notebook presented as a calm public
site. It borrows the useful structural lessons of mitchellh.com—narrow
reading measure, strong typography, simple navigation, and articles treated as
documents—without copying its visual identity.

## Constraints

- Hugo and Markdown are the primary authoring workflow.
- Generated output is static HTML; there is no application server or database.
- JavaScript is absent unless a future article has a concrete need for it.
- The first navigation is About, Writing, and Misc.
- The palette is adapted from Monkeytype's 80s After Dark theme: deep indigo,
  pale text, pink, blue, and a restrained yellow highlight.
- The sidebar identity uses a locally stored, transparent head-only profile
  illustration derived from the supplied source artwork.
- Atkinson Hyperlegible is served locally in regular, italic, bold, and bold
  italic weights. Only code uses the system monospace stack.
- At desktop sizes the page uses a 64rem shell, a 12.5rem navigation sidebar,
  and a 51.5rem main region. Long-form reading content is limited to 38.625rem.
- Desktop article text is 1rem with a 1.75 line height; page titles are compact
  at 1.0625rem. The shell stacks into a single column below 48rem.
- Demo content uses `demo: true` front matter and `demo-` filename prefixes so
  it remains subtly identified in the UI and easy to remove from the source.

## Naming

The repository and folder name is `astrochan-blog`: direct, searchable, and
personal enough to remain useful while the site's public title and visual
language evolve.
