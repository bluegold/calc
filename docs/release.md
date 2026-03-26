# Release Guide

This project ships releases from Git tags. The release workflow builds the gem and publishes it as a GitHub Release asset.

## Before Releasing

- Make sure `bundle exec rake test` passes.
- Make sure `bundle exec rubocop` passes.
- Update `lib/calc/version.rb`.
- Update `README.md` examples that mention the gem filename.
- Update `docs/TODO.md` and `docs/daily-log.md` if the release closes out work.

## Cut the Tag

```bash
git tag v0.3.1
git push origin master
git push origin v0.3.1
```

Use the version from `lib/calc/version.rb` when naming the tag.

## What the Workflow Does

- Triggers on `v*` tag pushes.
- Checks out the repository.
- Sets up Ruby.
- Installs dependencies with Bundler.
- Builds the gem with `gem build calc.gemspec`.
- Creates or updates the GitHub Release for the tag.
- Uploads the built `.gem` file as a release asset.

## After Releasing

- Confirm the GitHub Release exists and includes the gem asset.
- Confirm the release notes mention the tag.
- If a release needs to be re-run, push a new tag instead of rewriting an existing one.
