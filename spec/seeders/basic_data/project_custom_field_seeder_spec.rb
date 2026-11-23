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

RSpec.describe BasicData::ProjectCustomFieldSeeder do
  include_context "with basic seed data"

  subject(:seeder) { described_class.new(seed_data) }

  let(:seed_data) { basic_seed_data.merge(Source::SeedData.new(data_hash)) }
  let(:data_hash) do
    YAML.load <<~SEEDING_DATA_YAML
      project_custom_field_sections:
        - reference: :default_project_attributes
          name: Project attributes
          position: 1
        - reference: :matter_details
          name: Matter details
          position: 2
      project_custom_fields:
        - reference: :matter_cf__client
          name: Client
          field_format: string
          searchable: true
        - reference: :matter_cf__practice_area
          name: Practice area
          field_format: list
          possible_values:
            - Litigation
            - Family law
        - reference: :matter_cf__statute_of_limitations
          name: Statute of limitations
          field_format: date
    SEEDING_DATA_YAML
  end

  context "with the sections seeded" do
    before do
      seeder.seed!
    end

    it "creates the fields in the matter details section, active in all projects", :aggregate_failures do
      section = ProjectCustomFieldSection.find_by!(name: "Matter details")

      expect(ProjectCustomField.order(:position).pluck(:name))
        .to eq(["Client", "Practice area", "Statute of limitations"])
      expect(ProjectCustomField.all).to all(have_attributes(custom_field_section_id: section.id,
                                                            is_for_all: true,
                                                            is_required: false))
      expect(ProjectCustomField.find_by!(name: "Client")).to have_attributes(field_format: "string", searchable: true)
      expect(ProjectCustomField.find_by!(name: "Practice area").possible_values.map(&:value))
        .to eq(["Litigation", "Family law"])
      expect(seed_data.find_reference(:matter_cf__client)).to eq(ProjectCustomField.find_by!(name: "Client"))
    end

    it "does not create the fields again when seeding a second time" do
      expect { described_class.new(basic_seed_data.merge(Source::SeedData.new(data_hash))).seed! }
        .not_to change(ProjectCustomField, :count)
    end
  end

  context "when the instance was seeded before the matter details section existed" do
    subject(:seeder) { described_class.new(Source::SeedData.new(data_hash)) }

    before do
      ProjectCustomFieldSection.where(name: "Matter details").delete_all
      seeder.seed!
    end

    it "adds the missing section after the existing ones" do
      expect(ProjectCustomFieldSection.order(:position).pluck(:name)).to eq(["Project attributes", "Matter details"])
      expect(ProjectCustomField.count).to eq(3)
    end
  end

  context "without project custom fields defined" do
    let(:data_hash) { { "nothing here" => "" } }

    before { seeder.seed! }

    it "creates nothing" do
      expect(ProjectCustomField.count).to eq(0)
    end
  end
end
