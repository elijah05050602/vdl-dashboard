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

RSpec.describe "Client and party registry", :skip_csrf, type: :rails_request do
  shared_let(:visible_matter) { create(:project, name: "People v. Santos") }
  shared_let(:hidden_matter) { create(:project, name: "Partner's private matter") }
  shared_let(:party) do
    create(:party, name: "Maria Santos", tin: "123456789000",
                   aliases_attributes: [{ name: "Ma. Reyes", alias_type: "maiden_name" }])
  end
  shared_let(:editor) do
    create(:user,
           global_permissions: %i[view_client_registry manage_client_registry],
           member_with_permissions: { visible_matter => %i[view_project] })
  end
  shared_let(:viewer) { create(:user, global_permissions: %i[view_client_registry]) }

  before do
    create(:matter_party, project: visible_matter, party:, role: "client")
    create(:matter_party, project: hidden_matter, party:, role: "adverse_party")
  end

  context "as a user who can edit the registry" do
    before { login_as(editor) }

    it "lists and searches the registry, including alternate names" do
      create(:party, :organization, name: "Globex Philippines, Inc.")

      get "/clients_and_parties", params: { q: "reyes" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maria Santos", "123-456-789-000", "2 matters")
      expect(response.body).not_to include("Globex")
    end

    it "shows a party with only the matters the user can see" do
      get "/clients_and_parties/#{party.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("People v. Santos", "Ma. Reyes", "Maiden name",
                                       "Also linked to 1 matter you cannot see.")
      expect(response.body).not_to include("Partner&#39;s private matter")
    end

    it "adds a party with alternate names" do
      post "/clients_and_parties", params: {
        party: {
          kind: "organization", name: "Mabuhay Trading Corp.", tin: "987-654-321-00000",
          aliases_attributes: { "0" => { name: "MTC", alias_type: "abbreviation" },
                                "1" => { name: "", alias_type: "other_name" } }
        }
      }

      created = Party.find_by!(name: "Mabuhay Trading Corp.")
      expect(response).to redirect_to("/clients_and_parties/#{created.id}")
      expect(created).to have_attributes(kind: "organization", tin: "98765432100000", author: editor)
      expect(created.aliases.pluck(:name, :alias_type)).to eq([%w[MTC abbreviation]])
    end

    it "shows the form again with the errors when the TIN is invalid" do
      post "/clients_and_parties", params: { party: { kind: "person", name: "Pedro Penduko", tin: "123" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("must have 9 digits")
      expect(Party.where(name: "Pedro Penduko")).not_to exist
    end

    it "edits a party and removes an alternate name" do
      party_alias = party.aliases.first

      patch "/clients_and_parties/#{party.id}", params: {
        party: { name: "Maria Santos-Cruz",
                 aliases_attributes: { "0" => { id: party_alias.id, name: party_alias.name, _destroy: "1" },
                                       "1" => { name: "Maria Santos", alias_type: "former_name" } } }
      }

      expect(response).to redirect_to("/clients_and_parties/#{party.id}")
      expect(party.reload.name).to eq("Maria Santos-Cruz")
      expect(party.aliases.pluck(:name)).to eq(["Maria Santos"])
    end

    it "does not delete a party that is linked to matters" do
      delete "/clients_and_parties/#{party.id}"

      expect(response).to redirect_to("/clients_and_parties/#{party.id}")
      expect(Party.exists?(party.id)).to be(true)
    end

    it "deletes a party with no matters" do
      unlinked = create(:party)

      delete "/clients_and_parties/#{unlinked.id}"

      expect(response).to redirect_to("/clients_and_parties")
      expect(Party.exists?(unlinked.id)).to be(false)
    end
  end

  context "as a user who can only view the registry" do
    before { login_as(viewer) }

    it "shows the registry" do
      get "/clients_and_parties"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maria Santos")
      expect(response.body).not_to include("client-registry-new-party")
    end

    it "cannot add a party" do
      post "/clients_and_parties", params: { party: { kind: "person", name: "Intruder" } }

      expect(response).to have_http_status(:forbidden)
      expect(Party.where(name: "Intruder")).not_to exist
    end
  end

  context "as a user without registry permissions" do
    before { login_as(create(:user)) }

    it "is denied" do
      get "/clients_and_parties"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
