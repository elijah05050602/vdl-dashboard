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
