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

module DemoData
  module LawFirm
    class MatterTemplatesSeeder < ::Seeder
      SEED_FILE = Rails.root.join("app/seeders/law_firm/matter_templates.yml")
      DEFAULT_STATUS = :default_status_new
      TYPE_DEFAULT_STATUSES = { legal_type_contract_review: :legal_status_intake }.freeze

      self.needs = [
        BasicData::StatusSeeder,
        BasicData::TypeSeeder,
        BasicData::PrioritySeeder,
        BasicData::ProjectRoleSeeder,
        AdminUserSeeder
      ]

      def seed_data!
        pending_templates.each do |template_data|
          print_status "   -Creating matter template: #{template_data['name']}"
          TemplateBuilder.new(template_data, seed_data:, user: admin_user).create!
        end
      end

      def applicable?
        pending_templates.any? && super
      end

      def all_required_references
        references = templates.flat_map { |template_data| references_in(template_data["work_packages"]) }
        (references + [DEFAULT_STATUS, :default_role_project_admin] + TYPE_DEFAULT_STATUSES.values).uniq
      end

      def templates
        @templates ||= YAML.load_file(SEED_FILE).fetch("matter_templates").values
      end

      private

      def pending_templates
        templates.reject { |template_data| Project.exists?(identifier: template_data["identifier"]) }
      end

      def references_in(work_packages_data)
        Array(work_packages_data).flat_map do |work_package_data|
          work_package_data.values_at("type", "status").compact + references_in(work_package_data["children"])
        end
      end
    end
  end
end
