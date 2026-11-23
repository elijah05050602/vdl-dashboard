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

RSpec.describe "Conflict check", type: :rails_request do
  shared_let(:matter) { create(:project, name: "Doe v. Globex") }
  shared_let(:other_matter) { create(:project, name: "Partner's matter") }
  shared_let(:opposing_field) do
    create(:string_project_custom_field, name: "Opposing party", projects: [matter, other_matter])
  end
  shared_let(:user) do
    create(:user, member_with_permissions: { matter => %i[view_project view_project_attributes] })
  end

  before do
    create(:custom_value, custom_field: opposing_field, customized: matter, value: "Globex Corporation")
    create(:custom_value, custom_field: opposing_field, customized: other_matter, value: "Globex Corp.")
  end

  context "when logged in" do
    before { login_as(user) }

    it "shows the search form" do
      get "/conflict_check"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("conflict-check-query")
    end

    it "lists matching matters" do
      get "/conflict_check", params: { q: "Globex Corp." }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Doe v. Globex", "Globex Corporation", "Adverse party")
    end

    it "flags matters the user is not on without their details" do
      get "/conflict_check", params: { q: "Globex" }

      expect(response.body).to include("Restricted matter #{other_matter.identifier}")
      expect(response.body).not_to include("Partner&#39;s matter", "Globex Corp.<")
    end

    it "records who searched for what" do
      expect { get "/conflict_check", params: { q: "Globex" } }
        .to change(ConflictCheckLog, :count).by(1)

      log = ConflictCheckLog.last
      expect([log.user, log.query, log.matches_count, log.restricted_matches_count])
        .to eq([user, "Globex", 3, 1])
    end

    it "does not record an empty search" do
      expect { get "/conflict_check" }.not_to change(ConflictCheckLog, :count)
    end

    it "says when nothing matches" do
      get "/conflict_check", params: { q: "Initech" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No conflicts found")
    end
  end

  context "when logged in as admin" do
    before do
      login_as(create(:admin))
      create(:conflict_check_log, user:, query: "Earlier search")
    end

    it "shows the recent checks" do
      get "/conflict_check"

      expect(response.body).to include("Recent conflict checks", "Earlier search")
    end
  end

  context "when anonymous" do
    it "asks to log in and shows no results" do
      get "/conflict_check", params: { q: "Globex" }

      expect(response).to have_http_status(:found)
      expect(response.body).not_to include("Globex Corporation")
    end
  end
end
