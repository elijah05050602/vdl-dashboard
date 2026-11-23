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

module LawFirm
  # Creates the "VDL Firm" matter that every client matter sits under, its
  # firm-wide status board, and the firm welcome text. Safe to run again.
  class FirmSetup
    IDENTIFIER = "vdl-firm"
    MODULES = %w[work_package_tracking board_view calendar_view gantt costs meetings documents].freeze
    BOARD_STATUSES = ["Intake", "Conflict check", "Drafting", "Partner review", "Awaiting client",
                      "Filed", "Awaiting court", "Closed"].freeze

    class << self
      def firm_project
        Project.find_by(identifier: IDENTIFIER)
      end

      def firm_project_visible?(user = User.current)
        firm_project&.visible?(user) || false
      end

      def board
        project = firm_project
        project && ::Boards::Grid.where(project:).order(:id).first
      end
    end

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def call
      project = self.class.firm_project || create_project.tap { update_welcome_text }
      board = self.class.board || create_board(project)
      ServiceResult.success(result: board)
    end

    private

    def create_project
      Project.create!(
        name: I18n.t("law_firm.firm_setup.project_name"),
        identifier: IDENTIFIER,
        description: I18n.t("law_firm.firm_setup.project_description"),
        public: true,
        enabled_module_names: MODULES,
        project_types: Type.all.map { |type| ProjectType.new(type:) },
        workspace_type: "project"
      )
    end

    def create_board(project)
      widgets = board_statuses.each_with_index.map { |status, index| status_widget(project, status, index) }

      ::Boards::Grid.create!(
        project:,
        name: I18n.t("law_firm.firm_setup.board_name"),
        options: { "type" => "action", "attribute" => "status", "highlightingMode" => "priority" },
        widgets:,
        column_count: widgets.count,
        row_count: 1
      )
    end

    def board_statuses
      statuses = BOARD_STATUSES.filter_map { |name| Status.find_by(name:) }
      statuses.presence || Status.order(:position).to_a
    end

    def status_widget(project, status, index)
      Grids::Widget.new(start_row: 1, end_row: 2,
                        start_column: index + 1, end_column: index + 2,
                        identifier: "work_package_query",
                        options: { query_id: status_query(project, status).id,
                                   filters: [{ status: { operator: "=", values: [status.id.to_s] } }] })
    end

    def status_query(project, status)
      Query.new_default(project:, user:).tap do |query|
        query.public = true
        query.name = status.name
        query.include_subprojects = true
        query.add_filter("status_id", "=", [status.id])
        query.sort_criteria = [[:manual_sorting, "asc"]]
        query.save!
      end
    end

    def update_welcome_text
      {
        welcome_title: I18n.t("law_firm.firm_setup.welcome_title"),
        welcome_text: I18n.t("law_firm.firm_setup.welcome_text"),
        welcome_on_homescreen: true
      }.each do |name, value|
        Setting[name] = value if Settings::Definition[name].writable?
      end
    end
  end
end
