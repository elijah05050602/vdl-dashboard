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

RSpec.describe "Deadline calculator", type: :rails_request do
  shared_let(:court_deadline) { create(:type_milestone, name: "Court deadline") }
  shared_let(:task) { create(:type_task) }
  shared_let(:matter) { create(:project, types: [task, court_deadline]) }
  shared_let(:status) { create(:default_status) }
  shared_let(:priority) { create(:default_priority) }
  shared_let(:role) { create(:project_role, permissions: %i[view_work_packages add_work_packages]) }
  shared_let(:user) { create(:user, member_with_roles: { matter => role }) }

  let(:path) { "/projects/#{matter.identifier}/deadline_calculator" }
  let(:params) { { received_on: "2026-11-20", period: "notice_of_appeal" } }

  before do
    week_with_saturday_and_sunday_as_weekend
    login_as(user)
  end

  it "shows the form and the disclaimer" do
    get path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("deadline-calculator-received-on", "Rule 41, Sec. 3", "not legal advice")
  end

  it "computes the due date and explains the move to the next working day" do
    get path, params: params

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("12/07/2026", "Moved to the next working day")
  end

  it "computes a custom period" do
    get path, params: { received_on: "2026-11-23", period: "custom", custom_name: "Comment", custom_days: "10" }

    expect(response.body).to include("12/03/2026")
  end

  it "rejects an incomplete form" do
    get path, params: { received_on: "2026-11-23", period: "custom", custom_name: "Comment", custom_days: "0" }

    expect(response.body).to include("Enter the date of receipt")
    expect(response.body).not_to include("deadline-calculator-create")
  end

  it "creates the Court deadline in the matter" do
    expect { post path, params: params.merge(assigned_to_id: user.id) }
      .to change(WorkPackage, :count).by(1)

    work_package = WorkPackage.last
    expect(response).to redirect_to("/projects/#{matter.identifier}/work_packages/#{work_package.id}")
    expect(work_package).to have_attributes(
      project: matter,
      type: court_deadline,
      subject: "Notice of appeal from the RTC (ordinary appeal)",
      start_date: Date.new(2026, 12, 7),
      due_date: Date.new(2026, 12, 7),
      assigned_to: user
    )
    expect(work_package.description).to include("Rule 41, Sec. 3", "November 20, 2026", "Rule 22, Sec. 1")
  end

  context "when the matter does not use the Court deadline type" do
    before { matter.types.delete(court_deadline) }

    it "says so and does not create anything" do
      expect { post path, params: }.not_to change(WorkPackage, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("does not use the Court deadline type")
    end
  end

  context "without permission to add work packages" do
    let(:viewer) { create(:user, member_with_permissions: { matter => %i[view_work_packages] }) }

    before { login_as(viewer) }

    it "is forbidden" do
      get path

      expect(response).to have_http_status(:forbidden)
    end
  end
end
