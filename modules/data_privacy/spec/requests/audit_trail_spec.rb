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

RSpec.describe "Audit trail", type: :rails_request do
  shared_let(:project) { create(:project, name: "Santos annulment") }
  shared_let(:work_package) { create(:work_package, project:, subject: "Petition draft") }
  shared_let(:user) do
    create(:user,
           member_with_permissions: {
             project => %i[view_project view_work_packages export_work_packages view_data_privacy_consents
                           manage_data_privacy_consents]
           })
  end

  let(:events) { DataPrivacy::AuditEvent.order(:id) }

  before do
    Rails.cache.clear
    login_as(user)
  end

  it "records a matter page view with the user, matter and address" do
    get "/projects/#{project.identifier}/data_privacy"

    expect(response).to have_http_status(:ok)
    event = events.last
    expect([event.action, event.user, event.project, event.description, event.http_method])
      .to eq(["view", user, project, "data_privacy/consents#index", "GET"])
    expect(event.remote_ip).to be_present
  end

  it "records a work package opened through the API" do
    get "/api/v3/work_packages/#{work_package.id}"

    expect(response).to have_http_status(:ok)
    expect(events.last).to have_attributes(action: "view", resource: work_package, project:)
  end

  it "records a list export" do
    get "/projects/#{project.identifier}/work_packages.csv"

    expect(events.last).to have_attributes(action: "export", project:, description: "work_packages#index")
  end

  it "records a change" do
    post "/projects/#{project.identifier}/data_privacy",
         params: { consent: { data_subject: "Ana Santos", subject_role: "client",
                              consent_given_on: "2026-11-02", scope: "Case records" } }

    expect(events.last).to have_attributes(action: "change", project:, http_method: "POST",
                                           description: "data_privacy/consents#create")
  end

  it "records a file download" do
    attachment = create(:attachment, container: work_package, author: user)

    get "/api/v3/attachments/#{attachment.id}/content"

    expect(events.last).to have_attributes(action: "download", resource: attachment, project:)
  end

  it "records a repeated view once a minute" do
    expect do
      2.times { get "/api/v3/work_packages/#{work_package.id}" }
    end.to change(DataPrivacy::AuditEvent, :count).by(1)
  end

  it "does not record refused requests" do
    other_project = create(:project)

    expect { get "/projects/#{other_project.identifier}/data_privacy" }
      .not_to change(DataPrivacy::AuditEvent, :count)
  end

  it "does not record API form previews" do
    expect { post "/api/v3/work_packages/#{work_package.id}/form", params: {}.to_json, headers: { "CONTENT_TYPE" => "application/json" } }
      .not_to change(DataPrivacy::AuditEvent, :count)
  end
end
