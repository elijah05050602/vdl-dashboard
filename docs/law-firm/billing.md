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

## Invoices

Each matter has an *Invoices* page (next to *Time and costs*). Partners can issue invoices, and
anyone with the *View invoices* permission can list and download them.

1. Click **+ Invoice**, pick the billing period and fill in the client's registered name, address
   and TIN. The client details from the matter's last invoice are filled in for you.
2. Tick *Client withholds EWT* for corporate clients and pick 10% or 15%.
3. **Preview draft PDF** opens an unnumbered draft marked "THIS DOCUMENT IS NOT VALID FOR CLAIM
   OF INPUT TAX". Check it with the client if needed.
4. **Issue invoice** takes the next serial number. It can never be changed or reused.

An invoice contains the billable time (one line per lawyer, hours × rate), fees and disbursements
logged on the matter in the period that are not on another active invoice yet, so nothing is
billed twice. Non-billable activities are left out. A schedule listing every time entry and cost
follows on the next page.

The PDF shows what RR 7-2024 requires on an invoice (as amended after the Ease of Paying Taxes Act,
RA 11976): the word "Invoice" (default *SERVICE INVOICE*), the firm's registered name, "VAT Reg
TIN" with branch code and address, the serial number, the date, the client's name, address and
TIN, quantity, unit cost and description of each service, the breakdown into VATable, VAT-exempt
and zero-rated sales, VAT as a separate amount, the total, and at the bottom the Acknowledgement
Certificate Control Number, its date and the registered series range. EWT is shown below the total
with the amount due after withholding, and the client is asked for BIR Form 2307. The first download
is the original; later downloads are marked *REPRINT*.

To correct an invoice, cancel it with a reason and issue a new one. Cancelled invoices stay on the
list with a *CANCELLED* mark, keep their number, and their time and costs can be billed again. Keep
every copy of a cancelled invoice. A matter with issued invoices cannot be deleted; archive it
instead.

### Setting it up

Fill in the `invoice:` section of [`config/law_firm_billing.yml`](../../config/law_firm_billing.yml)
with the details on the firm's BIR Certificate of Registration (Form 2303) and restart the app:
registered name, TIN with branch code, registered address, the Acknowledgement Certificate number
and date, and the registered serial number range. Until the TIN, address and Acknowledgement
Certificate number are filled in, only drafts can be made.

- **VAT:** the 12% `vat_rate` is used. Leave it empty if the firm is not VAT-registered; invoices
  then say "Non-VAT Reg TIN" and show no VAT.
- **Disbursements** are part of VATable sales by default. Set `disbursements_vatable: false` only if
  the firm's accountant confirms they are reimbursements (for example official receipts issued in
  the client's name); they then show as VAT-exempt.
- **Fees or disbursements:** each cost type has a `kind` in the config. Only fees and time count
  for EWT.

### What the firm has to do with the BIR

The dashboard makes the invoices, but the BIR has to know about it before they are valid. Ask the
firm's accountant to confirm these with the firm's Revenue District Office (RDO):

1. **Register the dashboard as the firm's invoicing system** (a Computerized Accounting System or
   component) through the BIR's eAccReg / ORUS registration and get an **Acknowledgement
   Certificate** (RR 7-2024 Sec. 5(C)(2), RR 9-2009). Put its control number, date and the
   approved serial range in the config. Changing how invoices are numbered or computed later may
   be a "major enhancement" that needs a new certificate.
2. **Check the Certificate of Registration (Form 2303)** shows the right registered name, address,
   branch code and VAT registration, because the invoice must match it exactly.
3. **Stop issuing Official Receipts or Billing Statements as the sales document.** Under the EOPT
   Act these are only supplementary documents and are not valid for input tax; old official
   receipts may only be used as supplementary documents stamped "THIS DOCUMENT IS NOT VALID FOR
   CLAIM OF INPUT TAX".
4. **Keep the records:** issued and cancelled invoices, and the books, for the period the BIR
   requires, and file the sales in the VAT returns and the Summary List of Sales where required.
5. **E-invoicing:** if the firm is ever covered by the BIR Electronic Invoicing System (EIS), the
   invoices also need to be sent to the BIR electronically. This is not built in yet.
6. **Collect BIR Form 2307** from corporate clients for every EWT deducted, to claim the tax credit.
