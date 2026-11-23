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

module Homescreen
  module Blocks
    class FirmShortcuts < Grids::WidgetComponent
      Shortcut = Data.define(:key, :icon, :href)

      def title
        t("law_firm.shortcuts.title")
      end

      def render?
        current_user.logged?
      end

      def shortcuts
        [
          new_matter_shortcut,
          Shortcut.new(:matters, :briefcase, helpers.projects_path),
          Shortcut.new(:court_deadlines, :alert, helpers.law_firm_deadlines_path),
          firm_board_shortcut,
          Shortcut.new(:my_time, :clock,
                       helpers.url_for(controller: "/my/time_management", action: "index", date: "today", only_path: true)),
          Shortcut.new(:billing_reports, :graph,
                       helpers.url_for(controller: "/reporting/cost_reports", action: "index", project_id: nil,
                                       only_path: true))
        ].compact
      end

      private

      def new_matter_shortcut
        return unless current_user.allowed_globally?(:add_project)

        firm = LawFirm::FirmSetup.firm_project
        href = firm ? helpers.new_project_path(parent_id: firm.id) : helpers.new_project_path
        Shortcut.new(:new_matter, :plus, href)
      end

      def firm_board_shortcut
        return unless LawFirm::FirmSetup.firm_project_visible?(current_user)

        Shortcut.new(:firm_board, :"project-roadmap", helpers.law_firm_board_path)
      end
    end
  end
end
