# Law Firm Dashboard

This fork adapts OpenProject for a law firm. A project is a matter, and a work package is a piece of work on that matter.

## What this fork changes

Seed data in `app/seeders/standard.yml` (used on a fresh database):

- **Work package types:** Court deadline (milestone), Hearing (milestone), Filing, Legal research, Document review, Client communication, Contract review. The stock types stay so demo data and upgrades keep working.
- **Statuses:** Intake, Conflict check, Drafting, Partner review, Awaiting client, Filed, Awaiting court, with workflows for each legal type.
- **Time entry activities:** Legal research, Drafting, Client communication, Court appearance, Discovery and document review, Negotiation, Travel, Administrative (non-billable).
- **Welcome text** on the home page.
- **Sample matters** in place of OpenProject's demo and Scrum projects. All names and facts are fictional:
  - *Harlow v. Brightline Logistics* (`harlow-v-brightline`): commercial litigation with pleadings, discovery, court deadlines, hearings, a filings board, a team planner and a weekly case review meeting. The onboarding tour runs in this matter.
  - *Northwind Bakery supply agreement* (`northwind-supply-agreement`): a contract negotiation with a review, redline and signing timeline.
  - *Ellison estate plan* (`ellison-estate-plan`): trust, will and power of attorney drafting through signing and funding.

  The sample matters are only seeded on an empty database. Delete or archive them once you add real matters.

Branding is set by configuration, not code, so upstream merges stay easy. See `lawfirm.env.example`.

## License

OpenProject is GPLv3. If you run a modified version for others, or distribute it, you must publish the modified source under GPLv3 and keep the existing copyright notices and `LICENSE`, `COPYRIGHT` files.
