# Termclip Product Plan

## Must-have for launch

1. **Website + landing page** -- one page explaining the pain, showing a before/after, with a download button. Could be a simple GitHub Pages site or something on termclip.com
2. **Payment** -- Lemon Squeezy or Gumroad. Both handle one-time purchases with license keys. Low friction for "a few quid." No App Store needed.
3. **Install experience** -- `brew install termclip` is great for devs. But also a `.dmg` or `.pkg` for people who don't use Homebrew. One-line curl install is another option.
4. **License check** -- lightweight. Could be as simple as `termclip activate <key>` that writes to config. No DRM, just honesty-based.
5. **README / docs** -- already have the design doc, just needs polishing into user-facing docs

## Should-have for credibility

6. **App icon + branding** -- even though it's invisible, the website and Homebrew listing need identity
7. **Homebrew tap** -- `brew tap jonthebeef/termclip && brew install termclip` before getting into homebrew-core
8. **Onboarding** -- first run prints a friendly setup message, maybe `termclip setup` that walks through permissions

## Nice-to-have (v1.1 upsell / premium)

9. **Preferences UI** -- a tiny menu bar icon that appears only in System Settings or a `termclip config` TUI
10. **Custom terminal detection** -- `termclip add-terminal <bundle-id>`
11. **AI mode** -- for ambiguous cases, optional Claude API call (premium tier)
12. **Stats dashboard** -- `termclip stats` showing how many cleans, time saved

## Pricing thoughts

- $4-5 one-time feels right for a "buy me a coffee" utility
- Free tier: works for 7 days, then nags (not blocks)
- Or fully free + "pay what you want" on Gumroad
