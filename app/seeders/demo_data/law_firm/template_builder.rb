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
    class TemplateBuilder
      MODULES = %w[work_package_tracking gantt calendars board_view wiki documents costs meetings].freeze

      QUERIES = [
        {
          name: "Matter plan",
          timeline: true,
          hierarchy: true,
          starred: true,
          sort_by: "id",
          module: "gantt",
          columns: %w[id type subject status start_date due_date duration assigned_to]
        },
        {
          name: "Deadlines and hearings",
          status: "open",
          type: %i[legal_type_court_deadline legal_type_hearing default_type_milestone],
          starred: true,
          sort_by: "due_date",
          columns: %w[id type subject status due_date assigned_to]
        }
      ].freeze

      attr_reader :data, :seed_data, :user, :project

      def initialize(data, seed_data:, user:)
        @data = data
        @seed_data = seed_data
        @user = user
        @work_packages = {}
      end

      def create!
        @project = create_project
        Member.create!(project:, principal: user, roles: [seed_data.find_reference(:default_role_project_admin)])
        create_wiki_pages
        create_work_packages(data["work_packages"])
        create_queries
        project
      end

      private

      attr_reader :work_packages

      def create_project
        Project.create!(
          name: data["name"],
          identifier: data["identifier"],
          description: data["description"],
          templated: true,
          public: false,
          enabled_module_names: MODULES,
          project_types: Type.all.map { |type| ProjectType.new(type:) },
          workspace_type: "project"
        )
      end

      def create_wiki_pages
        pages = Array(data["wiki"])
        return if pages.empty?

        wiki = Wiki.find_or_create_by!(project:) { it.start_page = pages.first["title"] }
        pages.each do |page|
          WikiPage.create!(wiki:, title: page["title"], text: page["content"], author: user)
        end
      end

      def create_work_packages(items, parent: nil)
        Array(items).each do |item|
          if item["children"]
            create_summary(item, parent:)
          else
            create_step(item, parent:)
          end
        end
      end

      def create_summary(item, parent:)
        summary = WorkPackage.create!(base_attributes(item, parent:).merge(schedule_manually: false))
        create_work_packages(item["children"], parent: summary)

        children = summary.children.reload
        start_date = children.filter_map(&:start_date).min
        due_date = children.filter_map(&:due_date).max
        summary.update!(start_date:, due_date:, duration: working_days.duration(start_date, due_date))
        remember(item, summary)
      end

      def create_step(item, parent:)
        predecessor = predecessor_for(item)
        lag = item["lag"].to_i
        start_date = start_date_for(predecessor, lag)
        due_date = milestone?(item) ? start_date : working_days.due_date(start_date, step_duration(item))

        work_package = WorkPackage.create!(
          base_attributes(item, parent:).merge(
            start_date:,
            due_date:,
            duration: working_days.duration(start_date, due_date),
            ignore_non_working_days: false,
            schedule_manually: predecessor.nil?
          )
        )
        Relation.create!(from: work_package, to: predecessor, relation_type: Relation::TYPE_FOLLOWS, lag:) if predecessor
        remember(item, work_package)
      end

      def base_attributes(item, parent:)
        type = seed_data.find_reference(item["type"])
        {
          project:,
          parent:,
          author: user,
          subject: item["subject"],
          description: item["description"],
          type:,
          status: seed_data.find_reference(item["status"] || default_status_for(item["type"])),
          priority: IssuePriority.default
        }
      end

      def default_status_for(type_reference)
        MatterTemplatesSeeder::TYPE_DEFAULT_STATUSES.fetch(type_reference, MatterTemplatesSeeder::DEFAULT_STATUS)
      end

      def predecessor_for(item)
        return if work_packages.empty?

        reference = item["after"] || @anchor_reference
        work_packages.fetch(reference) do
          raise ArgumentError, "#{data['identifier']}: '#{item['subject']}' follows unknown step '#{reference}'"
        end
      end

      def start_date_for(predecessor, lag)
        return working_days.soonest_working_day(Date.current) if predecessor.nil?

        working_days.soonest_working_day(working_days.with_lag(predecessor.due_date || predecessor.start_date, lag))
      end

      def milestone?(item)
        seed_data.find_reference(item["type"]).is_milestone?
      end

      def step_duration(item)
        [item["duration"].to_i, 1].max
      end

      def remember(item, work_package)
        reference = item["reference"] || "wp_#{work_package.id}"
        @anchor_reference ||= reference
        work_packages[reference] = work_package
      end

      def create_queries
        QUERIES.each do |config|
          DemoData::QueryBuilder.new(config, project:, user:, seed_data:).create!
        end
      end

      def working_days
        @working_days ||= WorkPackages::Shared::WorkingDays.new
      end
    end
  end
end
