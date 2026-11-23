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

## Branding

- **Name:** the app title defaults to "VDL Dashboard" and the organization name to "Law Offices of Villanueva, Dorin & Lozano" in development and production (`config/constants/settings/definition.rb`). The test environment keeps the upstream defaults so upstream specs pass. Override with the variables in `lawfirm.env.example`, or under Administration. A value saved in Administration wins over the default.
- **Logo:** the firm's VD monogram replaces the OpenProject logo in the header (`logo_openproject_white_big.png`, `logo_openproject.png`), the mobile header (`icon_logo.svg`, `icon_logo_white.svg`), the favicons, the touch icon and the installable app icons (`pwa/`). The file names stay the same so upstream code and specs keep working. The sign-in page shows the monogram and the firm's name above the form.
- **Colors:** charcoal header `#2E2829` with the logo in gold `#C9A45C`, navy accent `#1F3A5F` for links and the selected menu item (`frontend/src/global_styles/openproject/_variable_defaults.scss`, `lib/open_project/custom_styles/color_themes.rb`).
- **Brand kit:** `brand/` holds transparent versions of the mark (charcoal, gold, white), square icons and the wordmarks, for letterhead, the website or the desktop app.
- **Emails:** the sender name comes from `mail_from`, for example `VDL Dashboard <dashboard@firm-domain>`.

The welcome text is seeded only on a fresh database. On an existing one, change it under Administration > System settings > General.

## Deadline reminders and daily digest

Every user gets one email a day at 7:00 in their own time zone (set under My account, Settings; the firm default is Asia/Manila via `OPENPROJECT_USER__DEFAULT__TIMEZONE`) about open **Court deadline** and **Hearing** work packages. It is sent only when there is something to report, and has three parts:

- **Your deadlines that need attention:** deadlines you are assigned to, accountable for or watching that are due in 14, 7, 3 or 1 days, due today, or overdue.
- **Overdue in your matters:** every overdue deadline in the matters (projects) you are a member of.
- **Coming up in the next 14 days:** every upcoming deadline in the matters you are a member of.

People can stop it by turning off **Daily email reminders** under My account, Notifications, Email reminders. Email delivery must be configured under Administration, Emails and notifications. The digest names clients and matters, so send it only through an SMTP server that uses TLS (Data Privacy Act of 2012, RA 10173).

Settings (change them with environment variables, for example `OPENPROJECT_DEADLINE__REMINDER__DAYS="[14, 7, 3, 1, 0]"`):

| Setting | Default |
| --- | --- |
| `deadline_digest_enabled` | `true` |
| `deadline_digest_hour` | `7` |
| `deadline_digest_days_ahead` | `14` |
| `deadline_reminder_days` | `[14, 7, 3, 1, 0]` |
| `deadline_reminder_types` | `["Court deadline", "Hearing"]` |

OpenProject's own date alerts (the bell icon) keep working alongside this, with each user's settings under My account, Notifications.

## Philippine holidays

Run `bundle exec rake law_firm:ph_holidays` to add this year's and next year's Philippine regular holidays and special non-working days as non-working days (`rake "law_firm:ph_holidays[2028]"` for one year). Chinese New Year, Eid'l Fitr and Eid'l Adha are proclaimed each year, so add those by hand under Administration, Calendars and dates, Working days and hours, and check the list against the year's proclamation.

The task does not move dates already entered. Under the Rules of Court, a deadline that falls on a holiday moves to the next working day: check those by hand.

## License

OpenProject is GPLv3. If you run a modified version for others, or distribute it, you must publish the modified source under GPLv3 and keep the existing copyright notices and `LICENSE`, `COPYRIGHT` files.
