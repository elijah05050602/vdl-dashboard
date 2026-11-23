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

require "rails_helper"

RSpec.describe LawFirm::FirmSetup do
  shared_let(:admin) { create(:admin) }
  shared_let(:intake) { create(:status, name: "Intake") }
  shared_let(:drafting) { create(:status, name: "Drafting") }
  shared_let(:closed) { create(:closed_status, name: "Closed") }

  subject(:setup) { described_class.new(user: admin) }

  it "creates the firm matter with a status board" do
    board = setup.call.result

    project = described_class.firm_project
    expect(project).to have_attributes(name: "VDL Firm", public: true)
    expect(board.project).to eq project
    expect(board.widgets.count).to eq 3
    expect(Query.where(project:).order(:id).pluck(:name)).to eq %w[Intake Drafting Closed]
    expect(Query.where(project:).pluck(:include_subprojects)).to all(be true)
  end

  it "sets the firm welcome text" do
    setup.call

    expect(Setting.welcome_title).to eq "Law Offices of Villanueva, Dorin & Lozano"
    expect(Setting.welcome_text).to include("Firm board")
  end

  it "does not duplicate the board or overwrite the welcome text when run again" do
    setup.call
    Setting.welcome_text = "Edited by an administrator"

    expect { setup.call }.not_to change(Boards::Grid, :count)
    expect(Setting.welcome_text).to eq "Edited by an administrator"
  end

  describe ".firm_project_visible?" do
    it "is false before setup" do
      expect(described_class.firm_project_visible?(admin)).to be false
    end

    it "is true for a logged in user once the public firm matter exists" do
      setup.call

      expect(described_class.firm_project_visible?(create(:user))).to be true
    end
  end
end
