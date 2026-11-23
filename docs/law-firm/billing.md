# Billing: hours, rates, expenses and budgets

Billing builds on OpenProject's own time tracking, cost and budget modules. The defaults live in
[`config/law_firm_billing.yml`](../../config/law_firm_billing.yml). Edit that file and run
`bin/rails db:seed` to apply it. Seeding only adds what is missing, so it is safe to run on a
database that is already in use, and it never changes records you edited by hand.

## What gets set up

- **Billing roles:** Partner ($450/h), Associate ($300/h), Paralegal ($150/h), Legal assistant ($90/h).
  Partners can see and edit everyone's time, rates, expenses and budgets. The other roles log
  and see their own time and expenses and can view budgets.
- **Automatic hourly rates:** when someone is added to a matter with a billing role, they get that
  role's rate on the matter, unless they already have one there. With several roles the highest
  rate wins. Change a person's rate on a matter in *Matter settings > Members* or on their profile.
  To give rates to people who were already on matters, run `bin/rails law_firm:apply_role_rates`.
- **Billable and non-billable time:** time logged as *Administrative*, *Pro bono* or *Business
  development* (the activities ending in "(non-billable)") is non-billable. Everything else is
  billable.
- **Expense types** for disbursements: court filing fees, service of process, photocopies,
  mileage, courier and expert witness, each with a unit rate. Log them on a work package with
  *Log unit costs*.
- **Budgets and time tracking** are switched on for new matters. Add a budget under *Budgets* in
  the matter: planned hours per person and planned expenses. The budget page shows spent against
  planned.
- **Currency** is set to `$` unless it was already changed in *Administration > Time and costs*.

## Reports

Three shared cost reports appear under *Time and costs* (global and in every matter):

| Report | Shows |
| --- | --- |
| Billable hours by matter | Billable hours per matter and timekeeper, by month |
| Billable amounts by matter | The same, as money (hours × rate) |
| Non-billable time by person | Non-billable hours per person and activity, by month |

Filter a report by date, client matter or person and save your own copy with *Save as*.
