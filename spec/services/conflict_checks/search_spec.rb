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

RSpec.describe ConflictChecks::Search do
  shared_let(:smith_matter) { create(:project, name: "Smith v. Acme Holdings") }
  shared_let(:jones_matter) { create(:project, name: "Jones estate") }
  shared_let(:hidden_matter) { create(:project, name: "Acme merger", public: false) }
  shared_let(:archived_matter) { create(:project, :archived, name: "Old estate case") }

  shared_let(:client_field) do
    create(:string_project_custom_field, name: "Client", projects: [smith_matter, jones_matter, archived_matter])
  end
  shared_let(:opposing_field) do
    create(:string_project_custom_field, name: "Opposing party", projects: [smith_matter, hidden_matter])
  end
  shared_let(:secret_field) do
    create(:string_project_custom_field, :admin_only, name: "Opposing counsel", projects: [jones_matter])
  end

  shared_let(:user) do
    create(:user, member_with_permissions: {
             smith_matter => %i[view_project view_project_attributes],
             jones_matter => %i[view_project view_project_attributes]
           })
  end

  before do
    create(:custom_value, custom_field: client_field, customized: smith_matter, value: "Jane Smith")
    create(:custom_value, custom_field: opposing_field, customized: smith_matter, value: "ACME Holdings, Inc.")
    create(:custom_value, custom_field: client_field, customized: jones_matter, value: "Robert Jones")
    create(:custom_value, custom_field: secret_field, customized: jones_matter, value: "Acme Holdings legal team")
    create(:custom_value, custom_field: opposing_field, customized: hidden_matter, value: "Acme Holdings LLC")
    create(:custom_value, custom_field: client_field, customized: archived_matter, value: "JONES, ROBERT S.")
  end

  subject(:matches) { described_class.new(query:, user:).call }

  describe ".normalize" do
    it "drops company suffixes, punctuation and case" do
      expect(described_class.normalize("ACME Holdings, Inc.")).to eq(%w[acme holdings])
    end

    it "keeps the words when only suffixes are given" do
      expect(described_class.normalize("The Company")).to eq(%w[the company])
    end
  end

  describe ".names_match?" do
    def match?(query, value)
      described_class.names_match?(described_class.normalize(query), value,
                                   described_class.normalize(query, expand: true))
    end

    it "treats Ma. as Maria and ignores middle initials and word order" do
      expect(match?("Maria Teresa Dela Cruz", "DELA CRUZ, MA. TERESA P.")).to be true
    end

    it "treats dela Cruz, de la Cruz and Delacruz alike" do
      expect(match?("Juan de la Cruz", "Juan Delacruz")).to be true
      expect(match?("Pedro delos Santos", "Pedro De Los Santos")).to be true
    end

    it "ignores Jr., III and titles" do
      expect(match?("Atty. Jose Rizal Jr.", "Jose Rizal III")).to be true
    end

    it "matches a stored name that leaves out the middle name" do
      expect(match?("Juan Reyes dela Cruz", "Juan dela Cruz")).to be true
    end

    it "ignores Philippine corporate endings" do
      expect(match?("ABC Trading OPC", "ABC Trading Corp.")).to be true
      expect(match?("Sta. Maria Holdings Inc.", "Santa Maria Holdings")).to be true
    end

    it "checks each name in a list of parties" do
      expect(match?("Maria Clara", "Juan dela Cruz; Maria Clara Ibarra")).to be true
    end

    it "finds a surname written without its particle" do
      expect(match?("Cruz", "Juan dela Cruz")).to be true
      expect(match?("Santos", "Pedro delos Santos")).to be true
    end

    it "treats Co as a surname" do
      expect(match?("Co", "Jimmy Co")).to be true
      expect(match?("Jimmy Co", "Jimmy Tan")).to be false
    end

    it "splits spouses who share a surname" do
      expect(match?("Juan Santos", "Spouses Juan and Maria Santos")).to be true
    end

    it "does not match different people who share one name" do
      expect(match?("Juan Santos", "Juan dela Cruz")).to be false
      expect(match?("Juan Santos", "Juan Reyes; Pedro Santos")).to be false
    end
  end

  describe ".role_for" do
    it "classifies field names" do
      expect(described_class.role_for("Opposing party")).to eq(:opposing)
      expect(described_class.role_for("Client")).to eq(:client)
      expect(described_class.role_for("Court")).to eq(:other)
      expect(described_class.role_for("Respondent")).to eq(:other)
    end
  end

  context "with a company name written differently" do
    let(:query) { "acme holdings llc" }

    it "finds matches across the whole firm, hiding details the user may not see" do
      expect(matches.map { |m| [m.project, m.role, m.restricted] })
        .to contain_exactly([smith_matter, :opposing, false],
                            [smith_matter, :matter, false],
                            [jones_matter, :opposing, true],
                            [hidden_matter, :opposing, true])
      expect(matches.first.role).to eq(:opposing)
    end

    it "leaves out the value and field name of restricted matches" do
      restricted = matches.select(&:restricted)
      expect(restricted.map(&:value)).to all(be_nil)
      expect(restricted.map(&:source)).to all(be_nil)
    end
  end

  context "with a client name" do
    let(:query) { "robert jones" }

    it "finds the existing client, including in archived matters" do
      expect(matches.map { |m| [m.project, m.source, m.role, m.restricted] })
        .to contain_exactly([jones_matter, "Client", :client, false],
                            [archived_matter, nil, :client, true])
      expect(matches.find { |m| m.project == archived_matter }).to be_archived
    end
  end

  context "when the user is an admin" do
    let(:user) { create(:admin) }
    let(:query) { "Acme" }

    it "sees the details of every match" do
      expect(matches.map(&:project)).to include(hidden_matter, jones_matter)
      expect(matches.map(&:restricted)).to all(be false)
    end
  end

  context "with an empty query" do
    let(:query) { "  " }

    it "returns nothing" do
      expect(matches).to be_empty
    end
  end
end
