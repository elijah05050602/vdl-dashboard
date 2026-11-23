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

RSpec.describe LawFirm::ApplyEngagementRatesService, type: :model do
  shared_let(:project) { create(:project, enabled_module_names: %w[costs]) }
  shared_let(:partner_role) { create(:project_role, name: "Partner") }
  shared_let(:associate_role) { create(:project_role, name: "Associate") }
  shared_let(:partner) { create(:user) }
  shared_let(:associate) { create(:user) }

  let(:config) do
    LawFirm::BillingConfig.new("billing_roles" => [{ "name" => "Partner", "hourly_rate" => 8000 },
                                                   { "name" => "Associate", "hourly_rate" => 3500 }])
  end

  before do
    create(:member, project:, principal: partner, roles: [partner_role])
    create(:member, project:, principal: associate, roles: [associate_role])
    create(:hourly_rate, user: partner, project:, rate: 8000, valid_from: 1.month.ago)
    LawFirm::EngagementTerms.create!(project:, role_rates: { "Partner" => "7000", "Associate" => "" })
  end

  subject(:call) { described_class.new(project, config:).call }

  it "starts the agreed rate today for people whose rate differs" do
    expect(call).to eq 2
    expect(HourlyRate.where(user_id: partner.id, project:).order(:valid_from).pluck(:rate, :valid_from))
      .to eq([[8000, 1.month.ago.to_date], [7000, Date.current]])
  end

  it "gives people without a rate the firm's standard rate for roles the terms leave blank" do
    call
    expect(HourlyRate.find_by(user_id: associate.id, project:).rate).to eq 3500
  end

  it "changes nothing when run again" do
    call
    expect { described_class.new(project, config:).call }.not_to change(HourlyRate, :count)
  end
end
