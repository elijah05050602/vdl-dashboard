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

RSpec.describe "Parties on a matter", :skip_csrf, type: :rails_request do
  shared_let(:matter) { create(:project, name: "Santos v. Globex") }
  shared_let(:client) { create(:party, name: "Maria Santos") }
  shared_let(:adverse) { create(:party, :organization, name: "Globex Philippines, Inc.") }
  shared_let(:manager) do
    create(:user, member_with_permissions: { matter => %i[view_project view_matter_parties manage_matter_parties] })
  end
  shared_let(:reader) do
    create(:user, member_with_permissions: { matter => %i[view_project view_matter_parties] })
  end

  let!(:client_link) { create(:matter_party, project: matter, party: client, role: "client") }

  context "as a member who can manage parties" do
    before { login_as(manager) }

    it "lists the parties with their roles and offers the registry" do
      get "/projects/#{matter.identifier}/parties"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maria Santos", "Globex Philippines, Inc.", "matter-party-form")
    end

    it "links a party in a role" do
      post "/projects/#{matter.identifier}/parties",
           params: { matter_party: { party_id: adverse.id, role: "adverse_party", notes: "Defendant" } }

      expect(response).to redirect_to("/projects/#{matter.identifier}/parties")
      expect(matter.matter_parties.find_by(party: adverse)).to have_attributes(role: "adverse_party", notes: "Defendant")
    end

    it "refuses to link the same party twice in one role" do
      post "/projects/#{matter.identifier}/parties",
           params: { matter_party: { party_id: client.id, role: "client" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("already has this role on the matter")
    end

    it "changes the role" do
      patch "/projects/#{matter.identifier}/parties/#{client_link.id}",
            params: { matter_party: { role: "related_party" } }

      expect(client_link.reload.role).to eq("related_party")
    end

    it "unlinks a party but keeps it in the registry" do
      delete "/projects/#{matter.identifier}/parties/#{client_link.id}"

      expect(MatterParty.exists?(client_link.id)).to be(false)
      expect(Party.exists?(client.id)).to be(true)
    end

    it "cannot touch the parties of another matter" do
      other_link = create(:matter_party, role: "witness")

      delete "/projects/#{matter.identifier}/parties/#{other_link.id}"

      expect(response).to have_http_status(:not_found)
      expect(MatterParty.exists?(other_link.id)).to be(true)
    end
  end

  context "as a member who can only view parties" do
    before { login_as(reader) }

    it "lists the parties without the form" do
      get "/projects/#{matter.identifier}/parties"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maria Santos", "Client")
      expect(response.body).not_to include("matter-party-form")
    end

    it "cannot link a party" do
      post "/projects/#{matter.identifier}/parties",
           params: { matter_party: { party_id: adverse.id, role: "adverse_party" } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  context "as a user who is not on the matter" do
    before { login_as(create(:user)) }

    it "does not show the parties" do
      get "/projects/#{matter.identifier}/parties"

      expect(response).to have_http_status(:not_found)
    end
  end
end
