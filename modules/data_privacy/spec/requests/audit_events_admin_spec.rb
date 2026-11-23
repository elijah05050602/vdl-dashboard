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

RSpec.describe "Audit trail administration", type: :rails_request do
  shared_let(:project) { create(:project, name: "Santos annulment") }
  shared_let(:other_project) { create(:project, name: "Reyes estate") }
  shared_let(:lawyer) { create(:user, firstname: "Maria", lastname: "Santos") }

  before do
    create(:data_privacy_audit_event, user: lawyer, project:, action: "export", path: "/santos/export.csv")
    create(:data_privacy_audit_event, user: lawyer, project: other_project, action: "view", path: "/reyes")
  end

  context "as an admin" do
    before { login_as(create(:admin)) }

    it "lists the events" do
      get "/admin/audit_trail"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maria Santos", "/santos/export.csv", "/reyes")
    end

    it "filters by matter and event" do
      get "/admin/audit_trail", params: { project_id: project.id, event: "export" }

      expect(response.body).to include("/santos/export.csv")
      expect(response.body).not_to include("/reyes")
    end

    it "downloads the events as CSV" do
      get "/admin/audit_trail.csv", params: { project_id: other_project.id }

      expect(response.media_type).to eq("text/csv")
      rows = CSV.parse(response.body)
      expect(rows.size).to eq(2)
      expect(rows.last).to include("Maria Santos", "view", "Reyes estate", "/reyes")
    end

    it "neutralizes formulas in the CSV" do
      create(:data_privacy_audit_event, user: lawyer, project:, path: "=HYPERLINK(\"x\")")

      get "/admin/audit_trail.csv", params: { project_id: project.id }

      expect(response.body).to include("'=HYPERLINK")
    end
  end

  context "as a regular user" do
    before { login_as(lawyer) }

    it "is refused" do
      get "/admin/audit_trail"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
