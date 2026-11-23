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

RSpec.describe LawFirm::ApplyRoleRateService, type: :model do
  shared_let(:project) { create(:project, enabled_module_names: %w[costs]) }
  shared_let(:partner_role) { create(:project_role, name: "Partner") }
  shared_let(:paralegal_role) { create(:project_role, name: "Paralegal") }
  shared_let(:other_role) { create(:project_role, name: "Observer") }
  shared_let(:user) { create(:user) }

  let(:config) do
    LawFirm::BillingConfig.new(
      "billing_roles" => [
        { "name" => "Partner", "hourly_rate" => 8000 },
        { "name" => "Paralegal", "hourly_rate" => 1500 }
      ]
    )
  end
  let(:roles) { [paralegal_role] }
  let(:member) { create(:member, project:, principal: user, roles:) }

  subject(:call) { described_class.new(member, config:).call }

  it "gives the member the hourly rate of their role on the matter" do
    expect { call }.to change(HourlyRate, :count).by(1)
    expect(HourlyRate.last).to have_attributes(user_id: user.id, project_id: project.id, rate: 1500,
                                               valid_from: Date.current)
  end

  context "with several billing roles" do
    let(:roles) { [paralegal_role, partner_role] }

    it "uses the highest rate" do
      call
      expect(HourlyRate.last.rate).to eq 8000
    end
  end

  context "with time already logged on the matter" do
    let!(:time_entry) do
      member
      create(:time_entry, entity: create(:work_package, project:), user:, spent_on: 10.days.ago, hours: 2)
    end

    it "starts the rate at the first logged day so that time is priced too" do
      call
      expect(HourlyRate.last.valid_from).to eq 10.days.ago.to_date
      expect(time_entry.reload.costs).to eq 3000
    end
  end

  context "with a role that has no rate" do
    let(:roles) { [other_role] }

    it "creates no rate" do
      expect { call }.not_to change(HourlyRate, :count)
    end
  end

  context "when the member already has a rate on the matter" do
    before { create(:hourly_rate, user:, project:, rate: 999) }

    it "keeps the existing rate" do
      expect { call }.not_to change(HourlyRate, :count)
    end
  end

  context "when time tracking is off for the matter" do
    let(:project) { create(:project, enabled_module_names: %w[work_package_tracking]) }

    it "creates no rate" do
      expect { call }.not_to change(HourlyRate, :count)
    end
  end

  context "when a member is added through the members service" do
    shared_let(:admin) { create(:admin) }

    it "applies the configured rate of the role" do
      allow(LawFirm::BillingConfig).to receive(:current).and_return(config)

      Members::CreateService
        .new(user: admin)
        .call(project:, principal: user, roles: [partner_role])

      expect(HourlyRate.find_by(user_id: user.id, project_id: project.id).rate).to eq 8000
    end
  end
end
