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
  `bin/rails law_firm:apply_role_rates`. A new rate also prices time the person logged on the
  matter earlier, unless that time was already priced with their default rate.
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

## VAT and withholding tax

OpenProject has no tax handling, so every amount it shows is the fee before tax. When preparing
the billing statement:

- **VAT:** add 12% (`vat_rate` in the config). Firms that are not VAT-registered set `vat_rate` to
  nothing and pay percentage tax instead.
- **Expanded withholding tax (EWT):** corporate and government clients withhold it from
  professional fees and give the firm BIR Form 2307. For a law firm it is 15% when the firm's
  gross income for the year exceeds ₱720,000, otherwise 10% (`ewt_rate` in the config, 15% by
  default). A lawyer billing as a sole practitioner uses 10%, or 5% with gross income up to
  ₱3 million. EWT is computed on the fee before VAT.
- **Government clients** also withhold 5% final VAT.

For a ₱100,000 fee to a corporate client: VAT ₱12,000, EWT ₱15,000, so the client pays
₱97,000 and the ₱15,000 is a tax credit for the firm. Individual clients usually do not
withhold.

`vat_rate` and `ewt_rate` are recorded for billing statements; nothing in OpenProject applies
them yet.

## Reports

Three shared cost reports appear under *Time and costs* (globally and in every matter):

| Report | Shows |
| --- | --- |
| Billable hours by matter | Billable hours per matter and lawyer, by month |
| Billable amounts by matter (before tax) | Billable time, fees and disbursements in pesos, before VAT and EWT |
| Non-billable time by person | Non-billable hours per person and activity, by month |

Filter a report by date, matter or person and save your own copy with *Save as*.

Non-billable time is recognised by the activity names in the config, so keep those names (they
are English in this setup) if you rename activities.
