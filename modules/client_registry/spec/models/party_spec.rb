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

RSpec.describe Party do
  describe "TIN" do
    it "stores only the digits and shows them grouped" do
      party = create(:party, tin: "123-456-789-00000")

      expect(party.tin).to eq("12345678900000")
      expect(party.formatted_tin).to eq("123-456-789-00000")
    end

    it "accepts a TIN without a branch code" do
      expect(build(:party, tin: "123 456 789")).to be_valid
    end

    it "rejects a TIN with the wrong number of digits" do
      party = build(:party, tin: "12345")

      expect(party).not_to be_valid
      expect(party.errors[:tin]).to be_present
    end

    it "rejects a TIN already in the registry" do
      create(:party, tin: "123-456-789-000")

      expect(build(:party, tin: "123456789000")).not_to be_valid
    end

    it "treats a blank TIN as not set" do
      expect(create(:party, tin: " ").tin).to be_nil
    end
  end

  describe "validation" do
    it "requires a name" do
      expect(build(:party, name: "  ")).not_to be_valid
    end

    it "only allows people and organizations" do
      expect(build(:party, kind: "robot")).not_to be_valid
    end

    it "checks the email format" do
      expect(build(:party, email: "not an email")).not_to be_valid
      expect(build(:party, email: " Juan@Example.PH ").tap(&:validate).email).to eq("juan@example.ph")
    end
  end

  describe "aliases" do
    it "saves alternate names given as nested attributes and skips empty rows" do
      party = create(:party, name: "Maria Cristina Santos",
                             aliases_attributes: [
                               { name: "Ma. Cristina Santos-Reyes", alias_type: "former_name" },
                               { name: "", alias_type: "other_name" }
                             ])

      expect(party.aliases.map(&:name)).to eq(["Ma. Cristina Santos-Reyes"])
      expect(party.all_names).to eq(["Maria Cristina Santos", "Ma. Cristina Santos-Reyes"])
    end

    it "rejects an unknown kind of name" do
      expect(build(:party_alias, alias_type: "secret")).not_to be_valid
    end
  end

  describe ".search" do
    shared_let(:santos) { create(:party, name: "Maria Santos", email: "maria@santos.ph", tin: "111-222-333") }
    shared_let(:globex) { create(:party, :organization, name: "Globex Philippines, Inc.") }
    shared_let(:alias_of_santos) { create(:party_alias, party: santos, name: "Maria Reyes", alias_type: "maiden_name") }

    it "finds by part of the name, ignoring case" do
      expect(described_class.search("globex")).to contain_exactly(globex)
    end

    it "finds by an alternate name" do
      expect(described_class.search("reyes")).to contain_exactly(santos)
    end

    it "finds by email" do
      expect(described_class.search("maria@santos")).to contain_exactly(santos)
    end

    it "finds by TIN with or without dashes" do
      expect(described_class.search("111-222")).to contain_exactly(santos)
      expect(described_class.search("111222333")).to contain_exactly(santos)
    end

    it "returns everyone for a blank search" do
      expect(described_class.search(" ")).to contain_exactly(santos, globex)
    end

    it "treats % and _ literally" do
      expect(described_class.search("%")).to be_empty
    end
  end

  describe "deletion" do
    it "is blocked while the party is linked to a matter" do
      party = create(:matter_party).party

      expect(party.destroy).to be(false)
      expect(party.errors).to be_present
    end

    it "removes the alternate names with the party" do
      party_alias = create(:party_alias)

      party_alias.party.destroy

      expect(PartyAlias.exists?(party_alias.id)).to be(false)
    end
  end
end
