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

module OpenProject::LawFirm
  # Trims OpenProject's global menu down to what a law office uses and adds
  # the firm shortcuts. Runs after every engine has registered its items.
  module Navigation
    HIDDEN_GLOBAL_ITEMS = %i[
      my_page
      portfolios
      activity
      gantt
      team_planners
      boards
      news
      wikis
      resource_management
    ].freeze

    HIDDEN_HOMESCREEN_BLOCKS = %w[new_features meetings my_account news community upsell].freeze

    module_function

    def enabled?
      !Rails.env.test? && ENV["OPENPROJECT_LAW_FIRM_SIMPLE_NAVIGATION"] != "false"
    end

    def apply!
      Redmine::MenuManager.map :global_menu do |menu|
        HIDDEN_GLOBAL_ITEMS.each { |name| menu.delete(name) }
        push_shortcuts(menu)
      end
    end

    def simplify_homescreen!
      OpenProject::Static::Homescreen.manage :blocks do |blocks|
        blocks.reject! { |block| HIDDEN_HOMESCREEN_BLOCKS.include?(block[:name]) }
        next if blocks.any? { |block| block[:name] == "firm_shortcuts" }

        welcome_index = blocks.index { |block| block[:name] == "welcome" }
        blocks.insert(welcome_index ? welcome_index + 1 : 0, { name: "firm_shortcuts" })
      end
    end

    def push_shortcuts(menu)
      return if menu.exists?(:law_firm_deadlines)

      menu.push :law_firm_deadlines,
                { controller: "/law_firm/shortcuts", action: "deadlines" },
                caption: ->(*) { I18n.t("law_firm.navigation.court_deadlines") },
                icon: "alert",
                after: :projects,
                if: ->(*) { User.current.logged? }

      menu.push :law_firm_board,
                { controller: "/law_firm/shortcuts", action: "board" },
                caption: ->(*) { I18n.t("law_firm.navigation.firm_board") },
                icon: "project-roadmap",
                after: :law_firm_deadlines,
                if: ->(*) { User.current.logged? && LawFirm::FirmSetup.firm_project_visible? }
    end
  end
end
