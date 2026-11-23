# VDL Dashboard

The matter dashboard for the Law Offices of Villanueva, Dorin & Lozano (VDL), a Philippine law firm. This fork adapts OpenProject for the firm. A project is a matter, and a work package is a piece of work on that matter. The interface stays in English, and courts, deadlines, templates, holidays, currency and time zone follow Philippine practice.

## What this fork changes

Seed data in `app/seeders/standard.yml` (used on a fresh database):

- **Work package types:** Court deadline (milestone), Hearing (milestone), Filing, Legal research, Document review, Client communication, Contract review. The stock types stay so demo data and upgrades keep working.
- **Statuses:** Intake, Conflict check, Drafting, Partner review, Awaiting client, Filed, Awaiting court, with workflows for each legal type.
- **Time entry activities:** Legal research, Drafting, Client communication, Court appearance, Document review, Negotiation, Notarial work, Travel, Administrative (non-billable).
- **Welcome text** on the home page.

## Court deadlines count calendar days

Philippine reglementary periods run in calendar days, and when the last day falls on a Saturday, Sunday or legal holiday, the deadline moves to the next working day (Rules of Court, Rule 22, Sec. 1). Stock OpenProject counts every gap between linked work packages in working days, so this fork changes that for one type:

- A **Court deadline** that follows another work package counts its lag in calendar days, starting the day after the step it follows. Lag 15 means the 15th day after. If that day is a weekend or a non-working day, the deadline moves to the next working day.
- Every other type keeps OpenProject's working-day lag. Those gaps are planning estimates.
- The switch is the `lag_in_calendar_days` column on types (migration `20261123140000_add_lag_in_calendar_days_to_types`). It is on for Court deadline only, and has no admin screen yet. The relation dialog still labels the lag "working days".

These dates are reminders, not legal advice. Always count from the actual date of receipt, and check the period against the current rules and any court order.

## Philippine holidays

Seeding adds the national regular holidays and special non-working days for 2026 and 2027 as non-working days (`app/seeders/law_firm/philippine_holidays.yml`, from Proclamation Nos. 1006, 1189, 1264 and 1427). Only nationwide non-working days are listed: a missing holiday can only make a deadline earlier, never later. Each year, and whenever the Palace or the Supreme Court declares a new holiday or court closure (including Eid'l Fitr and Eid'l Adha for 2027 and local holidays), add it under **Administration > Calendars and dates > Working days**, or add it to the YAML file and seed again.

## Matter templates

`bin/rails db:seed` creates nine template matters for Philippine practice, defined in `app/seeders/law_firm/matter_templates.yml`:

- Civil case (RTC), under the 2019 Amended Rules of Civil Procedure, with barangay conciliation, pre-trial, court-annexed mediation and post-judgment remedies
- Nullity or annulment of marriage, under A.M. No. 02-11-10-SC
- Labor case (NLRC), from SEnA to a Rule 65 petition
- Criminal complaint (preliminary investigation) before the prosecutor
- Corporation registration (SEC), then LGU, BIR, SSS, PhilHealth and Pag-IBIG
- Land title transfer (sale), with capital gains tax, documentary stamp tax, eCAR, transfer tax and Registry of Deeds
- Extrajudicial settlement of estate, under Rule 74
- Notarial work, under the Rules on Notarial Practice
- Contract review, under Philippine law

Each template has a step-by-step work package plan using the legal types and statuses, a "Matter plan" Gantt view, a "Deadlines and hearings" list, and wiki pages with an intake checklist and a key deadlines table. Each Court deadline's description cites the rule that sets the period.

To open a new matter from one, click **New matter**, pick the template from the list, and give the matter its name. In the new matter, move the first milestone (for example "Matter opened") to the real date, and move trigger milestones such as "Summons served on defendant" or "Decision expected" to the actual date of receipt. Every later step follows, so the whole plan moves with them.

Seeding only adds templates that are missing, so it is safe to run on a database that already has matters. It also archives the five earlier US-based templates (`retired_templates` in the YAML file) so they stop appearing in the template list. To change a template, edit it in the app, or edit the YAML file, delete the template matter and seed again.

## Philippine defaults

In development and production (`config/constants/settings/definition.rb` and `modules/costs/lib/costs/engine.rb`):

- Time zone **Asia/Manila** for users who have not picked one
- Dates like **Nov 23, 2026**, times like **01:30 PM**
- Currency **₱**, written before the amount (₱ 1,500.00)

A value saved in Administration wins over these defaults.

## Privacy and security defaults (Data Privacy Act)

Client data is personal and often sensitive personal information under the Data Privacy Act of 2012 (R.A. 10173). The fork sets these defaults in development and production:

- **Self-registration is off.** An administrator creates every account.
- **Sessions expire** after 60 minutes without activity.
- **AI features stay off.** The `ai_text_actions` feature flag is off by default; leave it off unless the firm has assessed where the text would be sent.

For the online server, also:

- **Require two-factor authentication** with an authenticator app: set `OPENPROJECT_2FA_ENFORCED="true"` and `OPENPROJECT_2FA_ACTIVE__STRATEGIES="[totp]"` (see `lawfirm.env.example`). It is not forced on the local development copy, so nobody gets locked out before setting up an app.
- **Encrypt backups.** Back up the database and attachments every day, encrypt the backup files (for example with `gpg` or `age`) before they leave the server, keep the key apart from the backups, and test a restore regularly.
- Use HTTPS only, and keep the server's operating system and the app up to date.
- Name a data protection officer and keep a record of processing, as the National Privacy Commission requires.

## Updating an existing database

Seed data only fills a fresh database. On the copy that is already running:

1. Run `bin/rails db:migrate` (turns on calendar-day counting for Court deadline).
2. Run `bin/rails db:seed` (adds the Philippine holidays and the new templates, and archives the US templates).
3. Under Administration > Time and costs > Time tracking activities, rename "Discovery and document review" to "Document review" and add "Notarial work", if you want them.
4. Change the welcome text under Administration > System settings > General.

## Branding

- **Name:** the app title defaults to "VDL Dashboard" and the organization name to "Law Offices of Villanueva, Dorin & Lozano" in development and production (`config/constants/settings/definition.rb`). The test environment keeps the upstream defaults so upstream specs pass. Override with the variables in `lawfirm.env.example`, or under Administration. A value saved in Administration wins over the default.
- **Logo:** the firm's VD monogram replaces the OpenProject logo in the header (`logo_openproject_white_big.png`, `logo_openproject.png`), the mobile header (`icon_logo.svg`, `icon_logo_white.svg`), the favicons, the touch icon and the installable app icons (`pwa/`). The file names stay the same so upstream code and specs keep working. The sign-in page shows the monogram and the firm's name above the form.
- **Colors:** charcoal header `#2E2829` with the logo in gold `#C9A45C`, navy accent `#1F3A5F` for links and the selected menu item (`frontend/src/global_styles/openproject/_variable_defaults.scss`, `lib/open_project/custom_styles/color_themes.rb`).
- **Brand kit:** `brand/` holds transparent versions of the mark (charcoal, gold, white), square icons and the wordmarks, for letterhead, the website or the desktop app.
- **Emails:** the sender name comes from `mail_from`, for example `VDL Dashboard <dashboard@firm-domain>`.

The welcome text is seeded only on a fresh database. On an existing one, change it under Administration > System settings > General.

## License

OpenProject is GPLv3. If you run a modified version for others, or distribute it, you must publish the modified source under GPLv3 and keep the existing copyright notices and `LICENSE`, `COPYRIGHT` files.
