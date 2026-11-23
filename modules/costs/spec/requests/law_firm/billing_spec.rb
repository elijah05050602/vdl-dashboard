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

RSpec.describe "Matter billing and receivables", :skip_csrf, type: :rails_request do
  shared_let(:project) { create(:project, enabled_module_names: %w[costs]) }
  shared_let(:partner) do
    create(:user, member_with_permissions: {
             project => %i[view_project view_law_firm_receivables manage_law_firm_receivables write_down_law_firm_entries]
           })
  end
  shared_let(:associate) { create(:user, member_with_permissions: { project => %i[view_project view_law_firm_receivables] }) }
  shared_let(:outsider) { create(:user, member_with_permissions: { project => %i[view_project] }) }
  shared_let(:work_package) { create(:work_package, project:) }

  let(:config) do
    LawFirm::BillingConfig.new("billing_roles" => [{ "name" => "Partner", "hourly_rate" => 8000 }],
                               "receivables" => { "payment_terms_days" => 15 })
  end
  let!(:invoice) do
    LawFirm::Invoice.create!(project:, serial: 1, number: "000001", issued_on: Date.current - 40,
                             period_from: Date.current - 70, period_to: Date.current - 41,
                             client_name: "ABC Holdings, Inc.", client_address: "Pasig City",
                             total_amount: 112_000, ewt_amount: 15_000, amount_due: 97_000)
  end
  let!(:time_entry) do
    create(:time_entry, entity: work_package, user: partner, hours: 2).tap { it.update_columns(costs: 16_000) }
  end

  before { allow(LawFirm::BillingConfig).to receive(:current).and_return(config) }

  context "as a partner" do
    current_user { partner }

    it "shows the receivables for the matter" do
      get project_billing_path(project)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("000001", "97,000.00")
    end

    it "records a payment and a BIR 2307" do
      post payments_project_billing_path(project),
           params: { payment: { invoice_id: invoice.id, received_on: Date.current, amount: "97000",
                                payment_method: "check", reference: "BPI 0042" } }
      post certificates_project_billing_path(project),
           params: { certificate: { invoice_id: invoice.id, received_on: Date.current, amount: "15000" } }

      expect(response).to redirect_to(project_billing_path(project))
      receivable = LawFirm::Receivable.for_projects(project, config:).first
      expect(receivable).to be_paid
      expect(receivable).not_to be_certificate_missing
    end

    it "keeps the retainer ledger" do
      post retainer_entries_project_billing_path(project),
           params: { retainer_entry: { entry_on: Date.current, kind: "deposit", amount: "50000" } }

      expect(LawFirm::RetainerEntry.balance(project)).to eq 50_000
    end

    it "lists unbilled time and writes it down" do
      get unbilled_project_billing_path(project)
      expect(response.body).to include("16,000.00")

      post write_downs_project_billing_path(project),
           params: { write_down: { entry_type: "TimeEntry", entry_id: time_entry.id, new_amount: "10000",
                                   reason: "Courtesy discount" } }

      expect(time_entry.reload.real_costs).to eq 10_000
    end

    it "saves the matter's terms" do
      get terms_project_billing_path(project)
      expect(response).to have_http_status(:ok)

      patch terms_project_billing_path(project),
            params: { engagement_terms: { withholds_ewt: "1", ewt_rate: "0.15", payment_terms_days: "30",
                                          role_rates: { "Partner" => "7500" } } }

      expect(LawFirm::EngagementTerms.for(project))
        .to have_attributes(withholds_ewt: true, ewt_rate: 0.15, payment_terms_days: 30)
      expect(LawFirm::EngagementTerms.for(project).role_rate("partner")).to eq 7500
    end

    it "shows the firm-wide aging" do
      get law_firm_receivables_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("000001", "ABC Holdings, Inc.")
    end
  end

  context "as an associate who may only look" do
    current_user { associate }

    it "shows the page but refuses payments" do
      get project_billing_path(project)
      expect(response).to have_http_status(:ok)

      post payments_project_billing_path(project),
           params: { payment: { invoice_id: invoice.id, received_on: Date.current, amount: "1", payment_method: "cash" } }
      expect(response).to have_http_status(:forbidden)
      expect(LawFirm::Payment.count).to eq 0
    end
  end

  context "as someone without access" do
    current_user { outsider }

    it "refuses the pages" do
      get project_billing_path(project)
      expect(response).to have_http_status(:forbidden)

      get law_firm_receivables_path
      expect(response).to have_http_status(:forbidden)
    end
  end
end
