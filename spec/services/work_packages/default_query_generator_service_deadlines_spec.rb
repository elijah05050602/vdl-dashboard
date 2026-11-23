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

RSpec.describe WorkPackages::DefaultQueryGeneratorService, "law firm deadline queries" do
  shared_let(:court_deadline) { create(:type, name: "Court deadline") }
  shared_let(:hearing) { create(:type, name: "Hearing") }
  shared_let(:task) { create(:type_task) }

  current_user { build_stubbed(:user) }

  def props(query_key, project: nil)
    JSON.parse(described_class.new(with_project: project).call(query_key:)[:query_props])
  end

  it "filters upcoming deadlines to open court deadlines and hearings due in the next 30 days", :aggregate_failures do
    filters = props(:upcoming_deadlines)["f"]

    expect(filters).to include({ "n" => "type", "o" => "=", "v" => contain_exactly(court_deadline.id.to_s, hearing.id.to_s) })
    expect(filters).to include({ "n" => "status", "o" => "o", "v" => [] })
    expect(filters).to include({ "n" => "dueDate", "o" => "<t+", "v" => ["30"] })
    expect(props(:upcoming_deadlines)["c"]).to include("project")
  end

  it "filters overdue deadlines to those due before today" do
    expect(props(:overdue_deadlines)["f"]).to include({ "n" => "dueDate", "o" => "<t-", "v" => ["1"] })
  end

  it "only uses the types enabled in a project and drops the project column" do
    project = create(:project, types: [hearing, task])

    expect(props(:upcoming_deadlines, project:)["f"].first["v"]).to eq([hearing.id.to_s])
    expect(props(:upcoming_deadlines, project:)["c"]).not_to include("project")
  end

  it "is omitted when the legal types are missing" do
    Type.where(id: [court_deadline.id, hearing.id]).delete_all

    expect(described_class.new(with_project: nil).call(query_key: :upcoming_deadlines)).to be_nil
  end
end
