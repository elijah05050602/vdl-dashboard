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

module BasicData
  class ProjectCustomFieldSeeder < ModelSeeder
    self.model_class = ProjectCustomField
    self.seed_data_model_key = "project_custom_fields"
    self.needs = [BasicData::ProjectCustomFieldSectionSeeder]
    self.attribute_names_for_lookups = %i[name]

    SECTION_REFERENCE = :matter_details

    def model_attributes(field_data)
      {
        name: field_data["name"],
        field_format: field_data["field_format"],
        possible_values: field_data["possible_values"],
        multi_value: true?(field_data["multi_value"]),
        searchable: true?(field_data["searchable"]),
        is_required: false,
        is_for_all: true,
        position: models_data.index(field_data) + 1,
        project_custom_field_section: section
      }.compact
    end

    def applicable?
      models_data.any? && ProjectCustomField.where(name: models_data.pluck("name")).none?
    end

    def not_applicable_message
      "Skipping project custom fields as they already exist"
    end

    private

    # Instances seeded before this section was added skip the section seeder, so it is created here.
    def section
      @section ||= seed_data.find_reference(SECTION_REFERENCE, default: nil) || create_section!
    end

    def create_section!
      section_data = Array(seed_data.lookup("project_custom_field_sections"))
                       .find { it["reference"] == SECTION_REFERENCE }
      ProjectCustomFieldSection
        .find_or_create_by!(name: section_data["name"]) do |new_section|
          new_section.position = ProjectCustomFieldSection.maximum(:position).to_i + 1
        end
        .tap { seed_data.store_reference(SECTION_REFERENCE, it) }
    end
  end
end
