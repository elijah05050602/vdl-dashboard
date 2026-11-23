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

RSpec.describe LawFirm::Invoices::PDF, type: :model do
  let(:project) { build_stubbed(:project, name: "ABC Holdings v. DEF Corp.") }
  let(:vat_rate) { BigDecimal("0.12") }
  let(:invoice) do
    LawFirm::Invoice.new(
      project:, number: "000101", issued_on: Date.new(2026, 11, 30),
      period_from: Date.new(2026, 11, 1), period_to: Date.new(2026, 11, 30),
      client_name: "ABC Holdings, Inc.", client_address: "Pasig City", client_tin: "987-654-321-00000",
      vatable_sales: 30_000, vat_exempt_sales: 0, zero_rated_sales: 0, vat_rate:, vat_amount: 3600,
      total_amount: 33_600, ewt_base: 30_000, ewt_rate: BigDecimal("0.1"), ewt_amount: 3000, amount_due: 30_600,
      lines: [{ "kind" => "time", "description" => "Professional services: Maria Villanueva", "quantity" => "2.5",
                "unit" => "hrs", "unit_cost" => "8000.0", "amount" => "20000.0", "vatable" => true },
              { "kind" => "fee", "description" => "Appearance fee", "quantity" => "2.0", "unit" => "hearings",
                "unit_cost" => "5000.0", "amount" => "10000.0", "vatable" => true }],
      details: [{ "kind" => "time", "date" => "2026-11-03", "person" => "Maria Villanueva", "activity" => "Legal research",
                  "description" => "Drafted the position paper", "quantity" => "2.5", "amount" => "20000.0" }],
      seller: { "title" => "SERVICE INVOICE", "registered_name" => "Law Offices of Villanueva, Dorin & Lozano",
                "tin" => "123-456-789-00000", "address" => "Makati City",
                "acknowledgement_certificate_no" => "AC-0001", "acknowledgement_certificate_date" => "11/23/2026",
                "series_range" => "000001 to 999999", "payment_terms" => "Payable within 15 days of receipt." }
    )
  end
  let(:draft) { false }
  let(:reprint) { false }

  subject(:text) do
    PDF::Inspector::Text.analyze(described_class.new(invoice, draft:, reprint:).render).strings.join(" ")
  end

  it "prints the information the BIR requires on an invoice" do
    expect(text).to include("SERVICE INVOICE", "No. 000101", "Law Offices of Villanueva, Dorin & Lozano",
                            "VAT Reg TIN 123-456-789-00000", "Makati City", "Nov 30, 2026",
                            "ABC Holdings, Inc.", "TIN: 987-654-321-00000",
                            "Professional services: Maria Villanueva", "2.50 hrs", "₱ 8,000.00",
                            "VATable sales", "VAT-exempt sales", "Zero-rated sales", "VAT (12%)", "₱ 3,600.00",
                            "Total amount (VAT inclusive)", "₱ 33,600.00",
                            "Less: EWT 10% on ₱ 30,000.00", "(₱ 3,000.00)", "₱ 30,600.00",
                            "Acknowledgement Certificate Control No.: AC-0001", "Series range: 000001 to 999999")
    expect(text).not_to include("REPRINT", "NOT VALID FOR CLAIM OF INPUT TAX")
  end

  it "adds the schedule of services" do
    expect(text).to include("Schedule of services and expenses for invoice 000101", "Drafted the position paper")
  end

  context "when printed again" do
    let(:reprint) { true }

    it "marks the copy as a reprint" do
      expect(text).to include("REPRINT")
    end
  end

  context "as a draft" do
    let(:draft) { true }

    it "is marked as a draft that is not valid for input tax" do
      expect(text).to include("DRAFT BILLING STATEMENT", "THIS DOCUMENT IS NOT VALID FOR CLAIM OF INPUT TAX.")
      expect(text).not_to include("No. 000101")
    end
  end

  context "for a firm that is not VAT-registered" do
    let(:vat_rate) { nil }

    it "says so and shows no VAT breakdown" do
      expect(text).to include("Non-VAT Reg TIN 123-456-789-00000")
      expect(text).not_to include("VATable sales")
    end
  end
end
