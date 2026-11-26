# VDL Dashboard

The matter dashboard for the Law Offices of Villanueva, Dorin & Lozano (VDL). This fork adapts OpenProject for the firm. A project is a matter, and a work package is a piece of work on that matter.

## What this fork changes

Seed data in `app/seeders/standard.yml` (used on a fresh database):

- **Work package types:** Court deadline (milestone), Hearing (milestone), Filing, Legal research, Document review, Client communication, Contract review. The stock types stay so demo data and upgrades keep working.
- **Statuses:** Intake, Conflict check, Drafting, Partner review, Awaiting client, Filed, Awaiting court, with workflows for each legal type.
- **Time entry activities:** Legal research, Drafting, Client communication, Court appearance, Discovery and document review, Negotiation, Travel, Administrative (non-billable).
- **Welcome text** on the home page.

## Matter templates

`bin/rails db:seed` creates five template matters, defined in `app/seeders/law_firm/matter_templates.yml`:

- Civil litigation
- Contract review
- Estate planning
- Real estate closing
- Employment dispute

Each template has a step-by-step work package plan using the legal types and statuses, a "Matter plan" Gantt view, a "Deadlines and hearings" list, and wiki pages with an intake checklist.

To open a new matter from one, click **New matter**, pick the template from the list, and give the matter its name. In the new matter, move the first milestone (for example "Matter opened") to the real date: every other step follows it with a gap in working days, so the whole plan moves with it. The gaps are common US defaults, so check them against the court's rules and the actual contract dates.

Seeding only adds templates that are missing, so it is safe to run on a database that already has matters. To change a template, edit it in the app, or edit the YAML file, delete the template matter and seed again.

## Hearings and the court calendar

The **Hearing** type has a "Hearing details" group with these work package custom fields, seeded by `BasicData::HearingDetailsSeeder` from `hearing_details` in `app/seeders/standard.yml`:

- **Hearing time:** half-hour slots from 7:00 AM to 6:00 PM. The hearing date is the work package's date.
- **Hearing kind:** arraignment, pre-trial, court-annexed mediation (CAM), JDR, trial, motion hearing, preliminary and mandatory conference, clarificatory hearing, oral arguments, promulgation.
- **Court:** the Philippine courts and the agencies the firm appears before (NLRC, NCMB, prosecutor, Ombudsman, SEC, DARAB).
- **Branch and station**, **Courtroom or sala**, **Presiding judge:** free text, for example "Branch 143, Makati City".
- **Appearance:** in person or videoconference.
- **Appearing lawyer:** a user.

Seeding runs on existing databases too: `bin/rails db:seed` adds the fields if none of them exist yet and a type named "Hearing" does. Admins can add or rename choices under Administration > Custom fields. The court calendar finds the fields and the type by name, so keep the names.

**Court calendar** (`/court_calendar`, in the main menu) shows every hearing the user can see across all matters, by month, week or day. Filter by lawyer (matches the appearing lawyer or, if none, the assignee) and by court. "My hearings" filters to the signed-in user. Weekends and the non-working days set under Administration > Calendars and dates are shaded, with the holiday name. Closed hearings stay on the calendar, faded.

## Branding

- **Name:** the app title defaults to "VDL Dashboard" and the organization name to "Law Offices of Villanueva, Dorin & Lozano" in development and production (`config/constants/settings/definition.rb`). The test environment keeps the upstream defaults so upstream specs pass. Override with the variables in `lawfirm.env.example`, or under Administration. A value saved in Administration wins over the default.
- **Logo:** the firm's VD monogram replaces the OpenProject logo in the header (`logo_openproject_white_big.png`, `logo_openproject.png`), the mobile header (`icon_logo.svg`, `icon_logo_white.svg`), the favicons, the touch icon and the installable app icons (`pwa/`). The file names stay the same so upstream code and specs keep working. The sign-in page shows the monogram and the firm's name above the form.
- **Colors:** charcoal header `#2E2829` with the logo in gold `#C9A45C`, navy accent `#1F3A5F` for links and the selected menu item (`frontend/src/global_styles/openproject/_variable_defaults.scss`, `lib/open_project/custom_styles/color_themes.rb`).
- **Brand kit:** `brand/` holds transparent versions of the mark (charcoal, gold, white), square icons and the wordmarks, for letterhead, the website or the desktop app.
- **Emails:** the sender name comes from `mail_from`, for example `VDL Dashboard <dashboard@firm-domain>`.

The welcome text is seeded only on a fresh database. On an existing one, change it under Administration > System settings > General.

## Putting it online

[HOSTING.md](HOSTING.md) explains how to run the dashboard on a server in Singapore with HTTPS, email, 2FA and encrypted nightly backups, and how to point the desktop app at it. The config files and scripts it uses are in `hosting/`.

## License

OpenProject is GPLv3. If you run a modified version for others, or distribute it, you must publish the modified source under GPLv3 and keep the existing copyright notices and `LICENSE`, `COPYRIGHT` files.
