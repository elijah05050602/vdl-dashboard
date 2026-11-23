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

RSpec.describe LawFirm::Receivables::WriteDownService, type: :model do
  shared_let(:project) { create(:project, enabled_module_names: %w[costs]) }
  shared_let(:partner) { create(:admin) }
  shared_let(:work_package) { create(:work_package, project:) }

  let!(:time_entry) do
    create(:time_entry, entity: work_package, user: partner, hours: 2).tap { it.update_columns(costs: 16_000) }
  end
  let(:new_amount) { "12,000" }

  subject(:call) do
    described_class.new(user: partner, project:).call(entry: time_entry, new_amount:, reason: "Research overlap")
  end

  it "lowers what the entry bills for and keeps a record" do
    expect(call).to be_success
    expect(time_entry.reload.real_costs).to eq 12_000
    expect(LawFirm::WriteDown.last).to have_attributes(original_amount: 16_000, new_amount: 12_000,
                                                       reason: "Research overlap", user_id: partner.id)
  end

  context "with an amount that is not lower" do
    let(:new_amount) { "16000" }

    it "refuses it" do
      expect(call).to be_failure
      expect(time_entry.reload.overridden_costs).to be_nil
    end
  end

  context "when the entry is already on an invoice" do
    before do
      LawFirm::Invoice.create!(project:, serial: 1, number: "000001", issued_on: Date.current,
                               period_from: Date.current, period_to: Date.current,
                               client_name: "ABC Holdings, Inc.", client_address: "Pasig City",
                               time_entry_ids: [time_entry.id])
    end

    it "refuses it" do
      expect(call).to be_failure
      expect(LawFirm::WriteDown.count).to eq 0
    end
  end
end
