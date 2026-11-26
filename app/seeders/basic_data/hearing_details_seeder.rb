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
  class HearingDetailsSeeder < Seeder
    self.needs = [BasicData::TypeSeeder]

    def seed_data!
      fields = fields_data.map { |field_data| create_field!(field_data) }
      add_group_to_form(fields)
    end

    def applicable?
      fields_data.any? && hearing_type.present? && WorkPackageCustomField.where(name: field_names).none?
    end

    def not_applicable_message
      "Skipping hearing details as they already exist or there is no Hearing type"
    end

    private

    def create_field!(field_data)
      WorkPackageCustomField.create!(
        name: field_data["name"],
        field_format: field_data["field_format"],
        possible_values: field_data["possible_values"],
        searchable: ActiveRecord::Type::Boolean.new.cast(field_data["searchable"]) || false,
        is_required: false,
        is_for_all: true,
        is_filter: true
      )
    end

    def add_group_to_form(fields)
      variant = hearing_type.default_variant
      keys = fields.map(&:attribute_name)
      groups = variant.attribute_groups.reject { |group| group.key == group_name }
      variant.attribute_groups = groups.insert([groups.size, 1].min, [group_name, keys])
      variant.save!
    end

    def hearing_type
      return @hearing_type if defined?(@hearing_type)

      @hearing_type = seed_data.find_reference(seed_data.lookup("hearing_details.type"), default: nil) ||
                      ::Type.find_by(name: LawFirm::Hearings::TYPE_NAME)
    end

    def group_name
      seed_data.lookup("hearing_details.group_name")
    end

    def fields_data
      Array(seed_data.lookup("hearing_details.custom_fields"))
    end

    def field_names
      fields_data.pluck("name")
    end
  end
end
