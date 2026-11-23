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

require "spec_helper"

RSpec.describe MatterParty do
  shared_let(:project) { create(:project) }
  shared_let(:party) { create(:party) }

  it "only allows the known roles" do
    expect(build(:matter_party, project:, party:, role: "judge")).not_to be_valid
  end

  it "allows the same party on a matter in two roles, but not twice in one role" do
    create(:matter_party, project:, party:, role: "client")

    expect(build(:matter_party, project:, party:, role: "witness")).to be_valid
    expect(build(:matter_party, project:, party:, role: "client")).not_to be_valid
  end

  it "lists clients first, then adverse parties, then the others" do
    witness = create(:matter_party, project:, party: create(:party, name: "A Witness"), role: "witness")
    adverse = create(:matter_party, project:, party: create(:party, name: "B Adverse"), role: "adverse_party")
    client = create(:matter_party, project:, party: create(:party, name: "C Client"), role: "client")

    expect(project.matter_parties.ordered).to eq([client, adverse, witness])
  end

  it "is removed when the matter is deleted" do
    link = create(:matter_party, project:, party:)

    project.destroy

    expect(described_class.exists?(link.id)).to be(false)
    expect(Party.exists?(party.id)).to be(true)
  end
end
