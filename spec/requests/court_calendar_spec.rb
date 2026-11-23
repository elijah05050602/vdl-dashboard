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

RSpec.describe "Court calendar", type: :rails_request, with_settings: { start_of_week: 1 } do
  shared_let(:hearing_type) { create(:type, name: "Hearing", is_milestone: true) }
  shared_let(:matter) { create(:project, name: "People v. Cruz", types: [hearing_type]) }
  shared_let(:other_matter) { create(:project, name: "Private matter", types: [hearing_type]) }
  shared_let(:user) { create(:user, member_with_permissions: { matter => %i[view_work_packages view_project] }) }
  shared_let(:court_field) { create(:list_wp_custom_field, name: "Court", possible_values: ["Regional Trial Court"]) }
  shared_let(:hearing) do
    create(:work_package, project: matter, type: hearing_type, subject: "Pre-trial conference",
                          start_date: Date.new(2026, 11, 10), due_date: Date.new(2026, 11, 10))
  end
  shared_let(:hidden_hearing) do
    create(:work_package, project: other_matter, type: hearing_type, subject: "Hidden hearing",
                          start_date: Date.new(2026, 11, 10), due_date: Date.new(2026, 11, 10))
  end

  before_all do
    CustomValue.insert_all!([{ custom_field_id: court_field.id, customized_type: "WorkPackage",
                               customized_id: hearing.id, value: court_field.custom_options.first.id.to_s }])
  end

  context "when logged in" do
    before { login_as(user) }

    it "shows the visible hearings of the month" do
      get "/court_calendar", params: { date: "2026-11-18" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Court calendar", "November 2026", "People v. Cruz")
      expect(response.body).not_to include("Hidden hearing", "Private matter")
    end

    %w[week day].each do |view|
      it "renders the #{view} view" do
        get "/court_calendar", params: { view:, date: "2026-11-10" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Pre-trial conference", "Regional Trial Court")
      end
    end

    it "shows an empty day" do
      get "/court_calendar", params: { view: "day", date: "2026-11-11" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No hearings")
    end

    it "filters by court" do
      get "/court_calendar", params: { view: "day", date: "2026-11-10", court: court_field.custom_options.first.id + 1 }

      expect(response.body).not_to include("Pre-trial conference")
    end
  end

  context "when not logged in" do
    it "asks to log in" do
      get "/court_calendar"

      expect(response).to redirect_to(%r{/login})
    end
  end
end
