# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require_relative "../../../spec_helper"

RSpec.describe LawFirm::Invoices::IssueService, type: :model do
  shared_let(:project) { create(:project, enabled_module_names: %w[costs]) }
  shared_let(:partner) do
    create(:user, member_with_permissions: { project => %i[view_law_firm_invoices issue_law_firm_invoices] })
  end
  shared_let(:lawyer) { create(:user, firstname: "Maria", lastname: "Villanueva") }
  shared_let(:work_package) { create(:work_package, project:) }
  shared_let(:research) { create(:time_entry_activity, name: "Legal research") }
  shared_let(:pro_bono) { create(:time_entry_activity, name: "Pro bono (non-billable)") }
  shared_let(:appearance_fee) { create(:cost_type, name: "Appearance fee", unit: "hearing", unit_plural: "hearings") }
  shared_let(:docket_fees) { create(:cost_type, name: "Docket and filing fees", unit: "peso", unit_plural: "pesos") }

  let(:invoice_settings) do
    {
      "registered_name" => "Law Offices of Villanueva, Dorin & Lozano",
      "tin" => "123-456-789-00000",
      "address" => "Makati City",
      "acknowledgement_certificate_no" => "AC-0001",
      "number_digits" => 6,
      "series_start" => 101,
      "series_end" => 999_999,
      "ewt_rates" => [0.10, 0.15]
    }
  end
  let(:config) do
    LawFirm::BillingConfig.new(
      "vat_rate" => 0.12,
      "ewt_rate" => 0.10,
      "non_billable_activities" => ["Pro bono (non-billable)"],
      "expense_types" => [
        { "name" => "Appearance fee", "kind" => "fee" },
        { "name" => "Docket and filing fees", "kind" => "disbursement" }
      ],
      "invoice" => invoice_settings
    )
  end
  let(:period) { { period_from: Date.new(2026, 11, 1), period_to: Date.new(2026, 11, 30) } }
  let(:withholds) { true }
  let(:request) do
    LawFirm::Invoices::Request.new(
      **period,
      client_name: "ABC Holdings, Inc.",
      client_address: "Pasig City",
      client_tin: "987-654-321-00000",
      client_withholds: withholds,
      ewt_rate: "0.1"
    ).tap { |req| req.allowed_ewt_rates = config.invoice.ewt_rates }
  end
  let(:user) { partner }

  subject(:call) { described_class.new(user:, project:, config:).call(request) }

  before do
    create(:hourly_rate, principal: lawyer, project:, rate: 8000, valid_from: Date.new(2026, 1, 1))
    create(:time_entry, entity: work_package, user: lawyer, activity: research, spent_on: Date.new(2026, 11, 3), hours: 2.5)
    create(:time_entry, entity: work_package, user: lawyer, activity: pro_bono, spent_on: Date.new(2026, 11, 4), hours: 4)
    create(:time_entry, entity: work_package, user: lawyer, activity: research, spent_on: Date.new(2026, 12, 2), hours: 1)
    create(:cost_entry, entity: work_package, user: lawyer, cost_type: appearance_fee, units: 2,
                        overridden_costs: 10_000, spent_on: Date.new(2026, 11, 10))
    create(:cost_entry, entity: work_package, user: lawyer, cost_type: docket_fees, units: 3530.5,
                        overridden_costs: 3530.5, spent_on: Date.new(2026, 11, 11))
  end

  it "issues an invoice with the first number of the series" do
    expect(call).to be_success
    expect(call.result).to have_attributes(serial: 101, number: "000101", issued_by: partner,
                                           client_name: "ABC Holdings, Inc.")
  end

  it "bills only billable time and costs within the period" do
    lines = call.result.lines.index_by { |line| line["description"] }

    expect(lines.keys).to contain_exactly("Professional services: Maria Villanueva", "Appearance fee",
                                          "Docket and filing fees")
    expect(lines["Professional services: Maria Villanueva"]).to include("quantity" => "2.5", "amount" => "20000.0")
    expect(lines["Appearance fee"]).to include("kind" => "fee", "quantity" => "2.0", "unit" => "hearings",
                                               "unit_cost" => "5000.0")
    expect(lines["Docket and filing fees"]).to include("kind" => "disbursement", "quantity" => "1.0")
  end

  it "computes VAT on the sales and EWT on the professional fees only" do
    expect(call.result).to have_attributes(
      vatable_sales: 33_530.5, vat_exempt_sales: 0, vat_amount: 4023.66,
      total_amount: 37_554.16, ewt_base: 30_000, ewt_rate: BigDecimal("0.1"), ewt_amount: 3000, amount_due: 34_554.16
    )
  end

  it "numbers invoices one after the other and never bills an entry twice" do
    first = call.result
    second = described_class.new(user:, project:, config:)
                            .call(LawFirm::Invoices::Request.new(**period.merge(period_to: Date.new(2026, 12, 31)),
                                                                 client_name: "ABC", client_address: "Pasig"))

    expect(second).to be_success
    expect(second.result.number).to eq "000102"
    expect(second.result.time_entry_ids & first.time_entry_ids).to be_empty
    expect(second.result.lines.pluck("quantity")).to eq ["1.0"]
  end

  it "makes the entries of a cancelled invoice billable again" do
    call.result.update!(cancelled_at: Time.current, cancelled_by: partner, cancellation_reason: "Wrong client")

    again = described_class.new(user:, project:, config:).call(request)
    expect(again.result.number).to eq "000102"
    expect(again.result.total_amount).to eq 37_554.16
  end

  context "when the client does not withhold" do
    let(:withholds) { false }

    it "leaves EWT out" do
      expect(call.result).to have_attributes(ewt_rate: nil, ewt_amount: 0, amount_due: 37_554.16)
    end
  end

  context "when disbursements are reimbursements" do
    let(:invoice_settings) { super().merge("disbursements_vatable" => false) }

    it "shows them as VAT-exempt" do
      expect(call.result).to have_attributes(vatable_sales: 30_000, vat_exempt_sales: 3530.5, vat_amount: 3600)
    end
  end

  context "when the firm's BIR details are still placeholders" do
    let(:invoice_settings) { super().merge("tin" => "000-000-000-00000", "acknowledgement_certificate_no" => "[ACCN]") }

    it "refuses to issue" do
      expect(call).to be_failure
      expect(call.errors.details[:base].pluck(:error)).to eq [:invoice_details_missing]
      expect(LawFirm::Invoice.count).to eq 0
    end
  end

  context "when the series is used up" do
    let(:invoice_settings) { super().merge("series_end" => 101) }

    it "refuses the next number" do
      call
      second = described_class.new(user:, project:, config:).call(request.dup.tap { |r| r.period_to = Date.new(2026, 12, 31) })

      expect(second).to be_failure
      expect(second.errors.details[:base].pluck(:error)).to eq [:invoice_series_exhausted]
    end
  end

  context "when nothing is left to bill" do
    let(:period) { { period_from: Date.new(2025, 1, 1), period_to: Date.new(2025, 1, 31) } }

    it "refuses to issue" do
      expect(call.errors.details[:base].pluck(:error)).to eq [:invoice_nothing_to_bill]
    end
  end

  context "without permission to issue invoices" do
    let(:user) { lawyer }

    it "refuses to issue" do
      expect(call.errors.details[:base].pluck(:error)).to eq [:invoice_unauthorized]
    end
  end

  it "keeps an issued invoice from being changed" do
    invoice = call.result

    expect(invoice.update(total_amount: 1)).to be false
    expect(invoice.reload.total_amount).to eq 37_554.16
  end
end
