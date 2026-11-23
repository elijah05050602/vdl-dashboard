# Billing: hours, fees, disbursements and budgets

Billing builds on OpenProject's own time tracking, cost and budget modules, set up for a
Philippine law office: amounts are in pesos (₱) and exclude 12% VAT. The defaults live in
[`config/law_firm_billing.yml`](../../config/law_firm_billing.yml). Edit that file and run
`bin/rails db:seed` to apply it. Seeding only adds what is missing, so it is safe to run on a
database that is already in use, and it does not change roles, activities, fee types or reports
that already exist.

## What gets set up

- **Billing roles and hourly rates:** Partner ₱8,000, Senior associate ₱5,000, Associate ₱3,500,
  Paralegal ₱1,500, Legal assistant ₱800 per hour. Partners can see and edit everyone's time,
  rates, fees and budgets. The other roles log and see their own time and fees and can view
  budgets.
- **Automatic hourly rates:** when someone is added to a matter with a billing role, they get that
  role's rate on the matter, unless they already have one there. With several roles the highest
  rate wins. Change a person's rate on a matter in the matter's *Members* page or on their
  profile. To give rates to people who were already on matters, run
  `bin/rails law_firm:apply_role_rates`.
- **Billable and non-billable time:** time logged as *Administrative*, *Pro bono* or *Business
  development* (the activities ending in "(non-billable)") is non-billable. Everything else is
  billable.
- **Fee arrangements**, logged on a matter with *Log unit costs*:

  | Fee | How it is logged |
  | --- | --- |
  | Acceptance fee | The agreed amount in pesos |
  | Appearance fee | Number of hearings, ₱5,000 each |
  | Monthly retainer | Number of months, ₱30,000 each |
  | Fixed fee | The agreed amount in pesos |
  | Success fee | The agreed amount in pesos |
  | Hourly | Log time; the person's hourly rate applies |

  Rates differ per client, so adjust the amount when logging, or change the default rate in
  *Administration > Time and costs > Cost types*.
- **Disbursements:** docket and filing fees, notarial fees (₱300 per document), photocopies
  (₱3 per page), courier (₱150 per delivery) and transportation.
- **Budgets and time tracking** are switched on for new matters. Add a budget under *Budgets* in
  the matter with the planned hours per person and planned fees. The budget page shows spent
  against planned.
- **Currency** is set to ₱, shown before the amount, unless it was already changed in
  *Administration > Time and costs*.

## VAT and withholding tax

OpenProject has no tax handling, so every amount it shows is the fee before tax. When preparing
the billing statement:

- **VAT:** add 12% (`vat_rate` in the config). Firms that are not VAT-registered set `vat_rate` to
  nothing and pay percentage tax instead.
- **Expanded withholding tax (EWT):** corporate clients withhold it from professional fees and
  give the firm BIR Form 2307. For a law firm partnership it is 10%, or 15% once a client's
  payments to the firm pass ₱720,000 in the year (`ewt_rate` in the config). EWT is computed on
  the fee before VAT.

For a ₱100,000 fee to a corporate client: VAT ₱12,000, EWT ₱10,000, so the client pays
₱102,000 and the ₱10,000 is a tax credit for the firm. Individual clients usually do not
withhold.

## Reports

Three shared cost reports appear under *Time and costs* (globally and in every matter):

| Report | Shows |
| --- | --- |
| Billable hours by matter | Billable hours per matter and lawyer, by month |
| Billable amounts by matter (excl. 12% VAT) | Billable time, fees and disbursements in pesos |
| Non-billable time by person | Non-billable hours per person and activity, by month |

Filter a report by date, matter or person and save your own copy with *Save as*.
