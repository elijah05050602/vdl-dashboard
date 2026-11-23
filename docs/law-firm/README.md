# Law Firm Dashboard

This fork adapts OpenProject for a law firm. A project is a matter, and a work package is a piece of work on that matter.

## What this fork changes

Seed data in `app/seeders/standard.yml` (used on a fresh database):

- **Work package types:** Court deadline (milestone), Hearing (milestone), Filing, Legal research, Document review, Client communication, Contract review. The stock types stay so demo data and upgrades keep working.
- **Statuses:** Intake, Conflict check, Drafting, Partner review, Awaiting client, Filed, Awaiting court, with workflows for each legal type.
- **Time entry activities:** Legal research, Drafting, Client communication, Court appearance, Discovery and document review, Negotiation, Travel, Administrative (non-billable).
- **Welcome text** on the home page.

Branding is set by configuration, not code, so upstream merges stay easy. See `lawfirm.env.example`.

## Deadline reminders and daily digest

Every user gets one email a day at 7:00 in their own time zone (set under My account, Settings) about open **Court deadline** and **Hearing** work packages. It is sent only when there is something to report, and has three parts:

- **Your deadlines that need attention:** deadlines you are assigned to, accountable for or watching that are due in 14, 7, 3 or 1 days, due today, or overdue.
- **Overdue at the firm:** every overdue deadline you can see.
- **Coming up in the next 14 days:** every upcoming deadline you can see.

People can stop it by turning off **Daily email reminders** under My account, Notifications, Email reminders. Email delivery must be configured under Administration, Emails and notifications.

Settings (change them with environment variables, for example `OPENPROJECT_DEADLINE__REMINDER__DAYS="[14, 7, 3, 1, 0]"`):

| Setting | Default |
| --- | --- |
| `deadline_digest_enabled` | `true` |
| `deadline_digest_hour` | `7` |
| `deadline_digest_days_ahead` | `14` |
| `deadline_reminder_days` | `[14, 7, 3, 1, 0]` |
| `deadline_reminder_types` | `["Court deadline", "Hearing"]` |

OpenProject's own date alerts (the bell icon) keep working alongside this, with each user's settings under My account, Notifications.

## License

OpenProject is GPLv3. If you run a modified version for others, or distribute it, you must publish the modified source under GPLv3 and keep the existing copyright notices and `LICENSE`, `COPYRIGHT` files.
