# VDL Dashboard

The matter dashboard for the Law Offices of Villanueva, Dorin & Lozano (VDL). This fork adapts OpenProject for the firm. A project is a matter, and a work package is a piece of work on that matter.

## What this fork changes

Seed data in `app/seeders/standard.yml` (used on a fresh database):

- **Work package types:** Court deadline (milestone), Hearing (milestone), Filing, Legal research, Document review, Client communication, Contract review. The stock types stay so demo data and upgrades keep working.
- **Statuses:** Intake, Conflict check, Drafting, Partner review, Awaiting client, Filed, Awaiting court, with workflows for each legal type.
- **Time entry activities:** Legal research, Drafting, Client communication, Court appearance, Discovery and document review, Negotiation, Travel, Administrative (non-billable).
- **Welcome text** on the home page.

## Branding

- **Name:** the app title defaults to "VDL Dashboard" and the organization name to "Law Offices of Villanueva, Dorin & Lozano" in development and production (`config/constants/settings/definition.rb`). The test environment keeps the upstream defaults so upstream specs pass. Override with the variables in `lawfirm.env.example`, or under Administration. A value saved in Administration wins over the default.
- **Logo:** the firm's VD monogram replaces the OpenProject logo in the header (`logo_openproject_white_big.png`, `logo_openproject.png`), the mobile header (`icon_logo.svg`, `icon_logo_white.svg`), the favicons, the touch icon and the installable app icons (`pwa/`). The file names stay the same so upstream code and specs keep working. The sign-in page shows the monogram and the firm's name above the form.
- **Colors:** charcoal header `#2E2829` with the logo in gold `#C9A45C`, navy accent `#1F3A5F` for links and the selected menu item (`frontend/src/global_styles/openproject/_variable_defaults.scss`, `lib/open_project/custom_styles/color_themes.rb`).
- **Brand kit:** `brand/` holds transparent versions of the mark (charcoal, gold, white), square icons and the wordmarks, for letterhead, the website or the desktop app.
- **Emails:** the sender name comes from `mail_from`, for example `VDL Dashboard <dashboard@firm-domain>`.

The welcome text is seeded only on a fresh database. On an existing one, change it under Administration > System settings > General.

## License

OpenProject is GPLv3. If you run a modified version for others, or distribute it, you must publish the modified source under GPLv3 and keep the existing copyright notices and `LICENSE`, `COPYRIGHT` files.
