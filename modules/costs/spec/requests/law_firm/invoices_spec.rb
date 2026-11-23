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

require_relative "../../spec_helper"

RSpec.describe "Matter invoices", :skip_csrf, type: :rails_request do
  shared_let(:project) { create(:project, enabled_module_names: %w[costs]) }
  shared_let(:partner) do
    create(:user, member_with_permissions: { project => %i[view_project view_law_firm_invoices issue_law_firm_invoices] })
  end
  shared_let(:associate) { create(:user, member_with_permissions: { project => %i[view_project view_law_firm_invoices] }) }
  shared_let(:outsider) { create(:user, member_with_permissions: { project => %i[view_project] }) }
  shared_let(:work_package) { create(:work_package, project:) }
  shared_let(:activity) { create(:time_entry_activity, name: "Court appearance") }

  let(:config) do
    LawFirm::BillingConfig.new(
      "vat_rate" => 0.12,
      "invoice" => {
        "registered_name" => "Law Offices of Villanueva, Dorin & Lozano", "tin" => "123-456-789-00000",
        "address" => "Makati City", "acknowledgement_certificate_no" => "AC-0001", "ewt_rates" => [0.10, 0.15]
      }
    )
  end
  let(:invoice_params) do
    { invoice: { period_from: "2026-11-01", period_to: "2026-11-30", client_name: "ABC Holdings, Inc.",
                 client_address: "Pasig City", client_tin: "987-654-321-00000", client_withholds: "1", ewt_rate: "0.1" } }
  end

  before do
    allow(LawFirm::BillingConfig).to receive(:current).and_return(config)
    create(:hourly_rate, principal: partner, project:, rate: 8000, valid_from: Date.new(2026, 1, 1))
    create(:time_entry, entity: work_package, user: partner, activity:, spent_on: Date.new(2026, 11, 5), hours: 3)
  end

  context "as a partner" do
    current_user { partner }

    it "shows the form with the unbilled amount" do
      get new_project_invoice_path(project)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Issue invoice")
    end

    it "takes the withholding from the matter's agreed terms" do
      LawFirm::EngagementTerms.create!(project:, withholds_ewt: true, ewt_rate: 0.15)

      get new_project_invoice_path(project)

      expect(response.body).to include('<option selected="selected" value="0.15">')
      expect(response.body).to match(/checked="checked"[^>]*id="invoice_client_withholds"/)
    end

    it "previews a draft without using a number" do
      expect { post draft_project_invoices_path(project), params: invoice_params }
        .not_to change(LawFirm::Invoice, :count)

      expect(response.media_type).to eq "application/pdf"
    end

    it "issues the invoice and lists it" do
      expect { post project_invoices_path(project), params: invoice_params }
        .to change(LawFirm::Invoice, :count).by(1)

      invoice = LawFirm::Invoice.last
      expect(invoice).to have_attributes(number: "000001", total_amount: 26_880, ewt_amount: 2400, amount_due: 24_480)
      expect(response).to redirect_to(project_invoices_path(project))

      get project_invoices_path(project)
      expect(response.body).to include("000001", "ABC Holdings, Inc.")
    end

    it "re-renders the form when the client is missing" do
      post project_invoices_path(project), params: { invoice: invoice_params[:invoice].merge(client_name: "") }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(LawFirm::Invoice.count).to eq 0
    end

    it "prints the original once and reprints after that" do
      post project_invoices_path(project), params: invoice_params
      invoice = LawFirm::Invoice.last

      get project_invoice_path(project, invoice)
      expect(response.media_type).to eq "application/pdf"
      expect(PDF::Inspector::Text.analyze(response.body).strings.join(" ")).not_to include("REPRINT")

      get project_invoice_path(project, invoice)
      expect(PDF::Inspector::Text.analyze(response.body).strings.join(" ")).to include("REPRINT")
      expect(invoice.reload.print_count).to eq 2
    end

    it "cancels an invoice with a reason and keeps it" do
      post project_invoices_path(project), params: invoice_params
      invoice = LawFirm::Invoice.last

      post cancel_project_invoice_path(project, invoice), params: { cancellation_reason: "Wrong client" }

      expect(invoice.reload).to be_cancelled
      expect(invoice).to have_attributes(cancelled_by: partner, cancellation_reason: "Wrong client")
    end
  end

  context "as an associate who may only view invoices" do
    current_user { associate }

    it "lists invoices but cannot issue them" do
      get project_invoices_path(project)
      expect(response).to have_http_status(:ok)

      post project_invoices_path(project), params: invoice_params
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "without invoice permissions" do
    current_user { outsider }

    it "is forbidden" do
      get project_invoices_path(project)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
