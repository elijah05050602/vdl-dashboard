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

RSpec.describe "Firm shortcuts", type: :rails_request do
  shared_let(:user) { create(:user) }

  current_user { user }

  it "opens the upcoming court deadlines list" do
    create(:type, name: "Court deadline")

    get law_firm_deadlines_path

    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("/work_packages").and include("upcoming_deadlines")
  end

  it "opens the firm board once it is set up" do
    board = LawFirm::FirmSetup.new(user: create(:admin)).call.result

    get law_firm_board_path

    expect(response).to redirect_to(project_work_package_board_path(board.project, board))
  end

  it "goes home with a notice when there is no firm board" do
    get law_firm_board_path

    expect(response).to redirect_to(home_path)
    expect(flash[:info]).to include("law_firm:setup_firm")
  end
end
