# Law firm module

`modules/law_firm` is the home for VDL Dashboard code. It is a Rails engine,
like the other OpenProject modules, so law-firm features stay apart from
OpenProject's own files and upstream updates merge with few conflicts. See
`docs/law-firm/UPGRADE-PLAN.md` for why.

## Put new law-firm code here

| What | Where |
| --- | --- |
| Models, services, jobs, mailers | `app/models/law_firm/`, `app/services/law_firm/`, `app/workers/law_firm/` |
| Controllers and views | `app/controllers/`, `app/views/` (routes in `config/routes.rb`) |
| Seeders and seed data | `app/seeders/` |
| English strings | `config/locales/en.yml` (write "matter", not "project") |
| Migrations | `db/migrate/` |
| Changes to OpenProject classes | `lib/open_project/law_firm/patches/`, registered with `patches` in the engine |
| Menus, settings, cron jobs | `lib/open_project/law_firm/engine.rb` |
| Specs | `spec/` |

Only edit files outside this folder when there is no hook for the change, and
list each such edit in `docs/law-firm/UPGRADE-PLAN.md`.

## Matter terminology

The English UI says "matter" instead of "project" through generated overrides in
`config/matter_terminology/en.yml`, loaded after every other locale file. They
are off in the test environment, and `OPENPROJECT_LAW_FIRM_MATTER_TERMINOLOGY=false`
turns them off elsewhere.

After merging upstream changes or adding English strings, regenerate them:

```shell
ruby modules/law_firm/script/generate_matter_terminology
```

Don't edit the generated file by hand.

## Firm navigation and home page

Outside the test environment the engine trims OpenProject to a law-office
workflow (`lib/open_project/law_firm/navigation.rb`):

- The left menu drops My page, Portfolios, Activity, Gantt charts, Team
  planners, Boards, News, Wikis and Resource management, and adds
  **Court deadlines** and **Firm board**.
- The home page drops New features, Meetings, My account, News, Community and
  the Enterprise upsell, and adds **Firm shortcuts**.

`OPENPROJECT_LAW_FIRM_SIMPLE_NAVIGATION=false` brings the stock menu back.

## Firm board

`bin/rails db:seed` (or `bin/rails law_firm:setup_firm`) creates the public
**VDL Firm** matter with a status board (Intake to Closed) and the firm welcome
text. Its board shows work from VDL Firm and all of its sub-matters, so new
matters should be opened under VDL Firm; the **New matter** shortcut does that.

## Removing sample data

`bin/rails law_firm:remove_sample_data` deletes OpenProject's demo and
developer projects (matched by their stock identifiers only) and locks the
sample `@example.net` users, whose passwords equal their logins. Administrators
are never locked.
