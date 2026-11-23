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

RSpec.describe LawFirm::Receivable, type: :model do
  shared_let(:project) { create(:project, enabled_module_names: %w[costs]) }

  let(:config) { LawFirm::BillingConfig.new("receivables" => { "payment_terms_days" => 15 }) }
  let!(:invoice) do
    LawFirm::Invoice.create!(project:, serial: 1, number: "000001", issued_on: Date.new(2026, 10, 1),
                             period_from: Date.new(2026, 9, 1), period_to: Date.new(2026, 9, 30),
                             client_name: "ABC Holdings, Inc.", client_address: "Pasig City",
                             total_amount: 112_000, ewt_amount: 15_000, amount_due: 97_000)
  end

  subject(:receivable) { described_class.for_projects(project, config:).first }

  it "is due after the firm's payment terms" do
    expect(receivable.due_on).to eq Date.new(2026, 10, 16)
    expect(receivable.balance).to eq 97_000
  end

  it "puts it in the bucket for how long it is overdue" do
    expect(receivable.bucket(Date.new(2026, 10, 16))).to eq "current"
    expect(receivable.bucket(Date.new(2026, 11, 15))).to eq "days_1_30"
    expect(receivable.bucket(Date.new(2026, 12, 20))).to eq "days_61_90"
    expect(receivable.bucket(Date.new(2027, 2, 1))).to eq "over_90"
  end

  it "uses the matter's own payment terms" do
    LawFirm::EngagementTerms.create!(project:, payment_terms_days: 30)

    expect(receivable.due_on).to eq Date.new(2026, 10, 31)
  end

  it "subtracts payments and tracks the BIR 2307 for the withheld tax" do
    LawFirm::Payment.create!(invoice:, amount: 97_000, payment_method: "check", received_on: Date.new(2026, 10, 10))
    LawFirm::WithholdingCertificate.create!(invoice:, amount: 10_000, received_on: Date.new(2026, 10, 10))

    expect(receivable).to be_paid
    expect(receivable).to be_certificate_missing

    LawFirm::WithholdingCertificate.create!(invoice:, amount: 5_000, received_on: Date.new(2026, 10, 20))
    expect(described_class.for_projects(project, config:).first).not_to be_certificate_missing
  end

  it "leaves out cancelled invoices" do
    invoice.update!(cancelled_at: Time.current, cancellation_reason: "Wrong client")

    expect(described_class.for_projects(project, config:)).to be_empty
  end
end
