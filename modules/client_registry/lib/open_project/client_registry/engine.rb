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

require "open_project/plugins"

module OpenProject::ClientRegistry
  class Engine < ::Rails::Engine
    engine_name :openproject_client_registry

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-client_registry",
             author_url: "https://github.com/elijah05050602/vdl-dashboard",
             bundled: true do
      Rails.application.reloader.to_prepare do
        OpenProject::AccessControl.map do |ac_map|
          ac_map.project_module nil do |map|
            map.permission :view_client_registry,
                           { parties: %i[index show] },
                           permissible_on: :global,
                           require: :loggedin

            map.permission :manage_client_registry,
                           { parties: %i[new create edit update destroy] },
                           permissible_on: :global,
                           require: :loggedin,
                           dependencies: :view_client_registry

            map.permission :view_matter_parties,
                           { matter_parties: %i[index] },
                           permissible_on: :project,
                           require: :member

            map.permission :manage_matter_parties,
                           { matter_parties: %i[create update destroy] },
                           permissible_on: :project,
                           require: :member,
                           dependencies: :view_matter_parties
          end
        end
      end

      menu :global_menu,
           :client_registry,
           { controller: "/parties", action: "index" },
           caption: :label_client_registry,
           after: :projects,
           icon: "people",
           if: ->(_) { User.current.allowed_globally?(:view_client_registry) }

      menu :project_menu,
           :matter_parties,
           { controller: "/matter_parties", action: "index" },
           caption: :label_matter_parties,
           after: :overview,
           icon: "people"
    end

    patches %i[Project]
  end
end
