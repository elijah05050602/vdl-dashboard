# Upgrade plan: move VDL Dashboard to a stable OpenProject release

Status: draft (2026-11-23). Investigation only. Nothing has been rebased.

## Findings

- The fork's `dev` is based on upstream `opf/openproject` `dev` at commit
  `46076e09` (version `18.1.0` in `lib/open_project/version.rb`). That is
  unreleased code: no `v18.*` tag exists upstream yet.
- The newest stable upstream release is **v17.9.8**, on branch `stable/17`.
- Law-firm work on `dev` so far (PRs #1, #2, #7, #8 merged at the time of
  writing, more open, e.g. #12) touches 35 files, about 3,100 added lines.
- Most of it already lives in law-firm-only paths, which never conflict:
  `docs/law-firm/`, `app/seeders/law_firm/`, `app/seeders/demo_data/law_firm/`,
  `config/law_firm/`, `script/law_firm/`, `spec/seeders/demo_data/law_firm/`,
  `app/assets/images/law_firm/`.
- Files shared with upstream (likely conflicts on any rebase or upstream merge):
  - `app/seeders/standard.yml` (legal types, statuses, activities)
  - `app/views/account/login.html.erb` (branding)
  - `config/constants/settings/definition.rb` (PH defaults)
  - `frontend/src/global_styles/openproject/_variable_defaults.scss`
  - `lib/open_project/custom_styles/color_themes.rb`
  - logo and favicon images under `app/assets/images/`
  - `README.md`, `spec/requests/pwa_manifest_spec.rb`
  - PR #12 adds a migration and edits `Relation`/`Type` (calendar-day lags),
    which also touches core code.

## Recommendation

1. **Wait for 18.0 rather than going back to 17.9.** Downgrading from 18.1-dev
   to 17.9.8 means database migrations written for 18.x may not exist in 17.x,
   and the local WSL database already ran them. A fresh database would be
   needed. Since 18.0 is the next stable release, the cheaper path is to rebase
   onto the `v18.0.0` tag (or `stable/18`) as soon as it ships. If Van wants a
   stable base now, 17.9.8 is possible but needs a fresh database.
2. **Move law-firm code into a plugin module, `modules/law_firm/`**, before the
   rebase. OpenProject modules are Rails engines (see `modules/` and the
   `Gemfile.modules` list). The engine can:
   - add seeders and run them after the standard seed instead of editing
     `standard.yml`;
   - prepend to `Relation`/`Type` for calendar-day deadlines (patches via
     `OpenProject::Plugins::ActsAsOpEngine` `patches`);
   - ship its own migrations, locales, assets and views (view override via
     the engine's `app/views` path for the login page);
   - set PH setting defaults from an initializer instead of editing
     `definition.rb`;
   - keep branding through env (`OPENPROJECT_APP__TITLE`) and custom theme
     settings rather than replacing upstream logo files.
   After this, upstream files stay untouched, so each upstream release merges
   with few or no conflicts.
3. **Order of work** (no force-push to `dev` while threads are merging):
   1. Let open PRs land on `dev`. Freeze `dev` briefly.
   2. Branch `law-firm/module`, move code into `modules/law_firm/`, and revert
      edits to upstream files. Merge to `dev`.
   3. Create `release/vdl-18.0` from upstream `v18.0.0`, cherry-pick or merge
      the module commits, run the specs, and test on Van's WSL install with a
      database backup.
   4. Make that the new default branch; keep old `dev` as `dev-18.1-archive`.
   5. Later upgrades: `git merge v18.x.y` into the release branch.

## Risks

- 18.1-dev migrations already applied locally. Back up the database before
  switching; a downgrade may need a fresh seed.
- Generated terminology overrides must be regenerated after each upstream merge
  (`script/law_firm/generate_matter_terminology`).
- Upstream specs for logos/PWA manifest may need adjusting if branding stays
  in core files.
