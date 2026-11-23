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

RSpec.describe "Data privacy consents", type: :rails_request do
  shared_let(:project) { create(:project, name: "Santos annulment") }
  shared_let(:lawyer) do
    create(:user, member_with_permissions: { project => %i[view_project view_data_privacy_consents
                                                            manage_data_privacy_consents] })
  end
  shared_let(:reader) do
    create(:user, member_with_permissions: { project => %i[view_project view_data_privacy_consents] })
  end
  shared_let(:outsider) { create(:user) }

  let(:path) { "/projects/#{project.identifier}/data_privacy" }
  let(:consent_params) do
    { data_subject: "Ana Santos", subject_role: "client", consent_given_on: "2026-11-02",
      scope: "Medical and civil registry records for the annulment petition", sensitive_personal_information: "1" }
  end

  context "as a lawyer on the matter" do
    before { login_as(lawyer) }

    it "records a consent with the signed form" do
      file = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 signed"), "application/pdf",
                                          original_filename: "consent.pdf")

      expect { post path, params: { consent: consent_params.merge(document: file) } }
        .to change(DataPrivacy::Consent, :count).by(1)

      consent = DataPrivacy::Consent.last
      expect(response).to redirect_to(path)
      expect(consent).to have_attributes(project:, author: lawyer, data_subject: "Ana Santos",
                                         consent_given_on: Date.new(2026, 11, 2),
                                         sensitive_personal_information: true)
      expect(consent.attachments.map(&:filename)).to eq(["consent.pdf"])
    end

    it "shows the form again when details are missing" do
      expect { post path, params: { consent: consent_params.merge(scope: "") } }
        .not_to change(DataPrivacy::Consent, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("data-privacy-errors")
    end

    it "lists the consents" do
      create(:data_privacy_consent, project:, data_subject: "Ana Santos")

      get path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ana Santos", "Record consent")
    end

    it "withdraws a consent and keeps the record" do
      consent = create(:data_privacy_consent, project:)

      patch "#{path}/#{consent.id}/withdraw",
            params: { consent: { withdrawn_on: "2026-11-20", withdrawal_notes: "Letter received" } }

      expect(response).to redirect_to(path)
      expect(consent.reload).to have_attributes(withdrawn_on: Date.new(2026, 11, 20),
                                                withdrawal_notes: "Letter received")
    end

    it "needs a withdrawal date" do
      consent = create(:data_privacy_consent, project:)

      patch "#{path}/#{consent.id}/withdraw", params: { consent: { withdrawn_on: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(consent.reload).not_to be_withdrawn
    end

    it "cannot delete a consent" do
      consent = create(:data_privacy_consent, project:)

      delete "#{path}/#{consent.id}"

      expect(response).to have_http_status(:forbidden)
      expect(DataPrivacy::Consent).to exist(consent.id)
    end

    it "cannot mark the matter confidential" do
      patch "#{path}/confidential", params: { confidential: true }

      expect(response).to have_http_status(:forbidden)
      expect(project.reload).not_to be_confidential
    end
  end

  context "as a member who may only read" do
    before { login_as(reader) }

    it "sees the consents but cannot record one" do
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Record consent")

      post path, params: { consent: consent_params }
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "as someone outside the matter" do
    before { login_as(outsider) }

    it "cannot see the consents" do
      create(:data_privacy_consent, project:, data_subject: "Ana Santos")

      get path

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("Ana Santos")
    end
  end

  context "as an admin" do
    before { login_as(create(:admin)) }

    it "marks the matter confidential and makes it private" do
      project.update_column(:public, true)

      patch "#{path}/confidential", params: { confidential: true }

      expect(response).to redirect_to(path)
      expect(project.reload).to have_attributes(confidential: true, public: false)
    end

    it "removes the confidential mark" do
      project.update_column(:confidential, true)

      patch "#{path}/confidential", params: { confidential: false }

      expect(project.reload).not_to be_confidential
    end

    it "deletes a consent" do
      consent = create(:data_privacy_consent, project:)

      expect { delete "#{path}/#{consent.id}" }.to change(DataPrivacy::Consent, :count).by(-1)
    end
  end
end
