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

RSpec.describe BasicData::HearingDetailsSeeder do
  include_context "with basic seed data"

  subject(:seeder) { described_class.new(seed_data) }

  let(:seed_data) { basic_seed_data.merge(Source::SeedData.new(data_hash)) }
  let(:data_hash) do
    YAML.load <<~SEEDING_DATA_YAML
      hearing_details:
        type: :legal_type_hearing
        group_name: Hearing details
        custom_fields:
          - name: Hearing time
            field_format: list
            possible_values:
              - "8:30 AM"
              - "1:30 PM"
          - name: Court
            field_format: list
            possible_values:
              - Regional Trial Court
              - Court of Appeals
          - name: Presiding judge
            field_format: string
            searchable: true
          - name: Appearing lawyer
            field_format: user
    SEEDING_DATA_YAML
  end
  let(:hearing_type) { Type.find_by!(name: "Hearing") }

  it "matches the field names the court calendar looks up" do
    standard_names = Source::SeedDataLoader.get_data(edition: "standard")
      .lookup("hearing_details.custom_fields")
      .pluck("name")

    expect(standard_names).to match_array(LawFirm::Hearings::FIELD_NAMES.values)
  end

  context "when seeding" do
    before { seeder.seed! }

    it "creates the fields active in every matter", :aggregate_failures do
      expect(WorkPackageCustomField.order(:id).pluck(:name))
        .to eq(["Hearing time", "Court", "Presiding judge", "Appearing lawyer"])
      expect(WorkPackageCustomField.all).to all(have_attributes(is_for_all: true, is_required: false))
      expect(WorkPackageCustomField.find_by!(name: "Presiding judge")).to have_attributes(searchable: true)
      expect(WorkPackageCustomField.find_by!(name: "Hearing time").possible_values.map(&:value))
        .to eq(["8:30 AM", "1:30 PM"])
    end

    it "shows them in a Hearing details group on the Hearing form only", :aggregate_failures do
      variant = hearing_type.reload.default_variant
      group = variant.attribute_groups.find { |g| g.key == "Hearing details" }
      field_keys = WorkPackageCustomField.order(:id).map(&:attribute_name)

      expect(group.attributes.map(&:to_s)).to eq(field_keys)
      expect(variant.attribute_groups.index(group)).to eq(1)
      expect(variant.custom_field_ids).to match_array(WorkPackageCustomField.ids)
      expect(Type.find_by!(name: "Court deadline").default_variant.custom_field_ids).to be_empty
    end

    it "does not create the fields again when seeding a second time" do
      expect { described_class.new(basic_seed_data.merge(Source::SeedData.new(data_hash))).seed! }
        .not_to change(WorkPackageCustomField, :count)
    end
  end

  context "when the Hearing type was renamed" do
    before do
      Type.find_by!(name: "Hearing").update!(name: "Court hearing")
      described_class.new(Source::SeedData.new(data_hash)).seed!
    end

    it "creates nothing" do
      expect(WorkPackageCustomField.count).to eq(0)
    end
  end
end
