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

RSpec.describe LawFirm::Receivables::RecordPaymentService, type: :model do
  shared_let(:project) { create(:project, enabled_module_names: %w[costs]) }
  shared_let(:user) { create(:admin) }

  let(:invoice) do
    LawFirm::Invoice.create!(project:, serial: 1, number: "000001", issued_on: Date.new(2026, 11, 1),
                             period_from: Date.new(2026, 10, 1), period_to: Date.new(2026, 10, 31),
                             client_name: "ABC Holdings, Inc.", client_address: "Pasig City",
                             total_amount: 112_000, ewt_amount: 15_000, amount_due: 97_000)
  end
  let(:amount) { 50_000 }
  let(:payment_method) { "bank_transfer" }

  subject(:call) do
    described_class.new(user:, invoice:)
                   .call(received_on: Date.new(2026, 11, 10), amount:, payment_method:, reference: "BDO 123")
  end

  it "records the payment" do
    expect(call).to be_success
    expect(LawFirm::Payment.last).to have_attributes(invoice_id: invoice.id, amount: 50_000, recorded_by_id: user.id)
  end

  context "with more than the balance" do
    let(:amount) { 97_000.01 }

    it "refuses it" do
      expect(call).to be_failure
      expect(LawFirm::Payment.count).to eq 0
    end
  end

  context "when paid from the retainer" do
    let(:payment_method) { "retainer" }

    before do
      LawFirm::RetainerEntry.create!(project:, kind: "deposit", amount: 60_000, entry_on: Date.new(2026, 10, 1))
    end

    it "draws the amount from the retainer" do
      expect(call).to be_success
      expect(LawFirm::RetainerEntry.balance(project)).to eq 10_000
      expect(LawFirm::RetainerEntry.find_by(kind: "drawdown")).to have_attributes(reference: "000001", amount: 50_000)
    end

    context "with more than the retainer holds" do
      let(:amount) { 60_000.01 }

      it "refuses it" do
        expect(call).to be_failure
        expect(call.errors.full_messages.join).to include("retainer")
        expect(LawFirm::RetainerEntry.balance(project)).to eq 60_000
      end
    end
  end
end
