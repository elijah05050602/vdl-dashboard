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

module OpenProject::DataPrivacy
  class Engine < ::Rails::Engine
    engine_name :openproject_data_privacy

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-data_privacy",
             author_url: "https://github.com/elijah05050602/vdl-dashboard",
             bundled: true do
      project_module :data_privacy do
        enabled_by_default!

        permission :view_data_privacy_consents,
                   { "data_privacy/consents": %i[index] },
                   permissible_on: :project
        permission :manage_data_privacy_consents,
                   { "data_privacy/consents": %i[new create edit update edit_withdrawal withdraw] },
                   permissible_on: :project,
                   require: :member,
                   dependencies: :view_data_privacy_consents
      end

      menu :project_menu,
           :data_privacy,
           { controller: "/data_privacy/consents", action: "index" },
           caption: :"data_privacy.menu",
           after: :members,
           icon: "shield-lock"

      menu :admin_menu,
           :audit_trail,
           { controller: "/data_privacy/audit_events", action: "index" },
           if: ->(_) { User.current.admin? },
           caption: :"data_privacy.audit.menu",
           after: :authentication,
           icon: "history"
    end

    initializer "data_privacy.audit_middleware" do |app|
      app.config.middleware.use OpenProject::DataPrivacy::AuditMiddleware
    end

    include_module "DataPrivacy::ProjectExtension", into: "Project"
    include_module "DataPrivacy::ConfidentialProjectContract", into: %w[Projects::CreateContract Projects::UpdateContract]
    include_module "DataPrivacy::ConfidentialShareContract", into: "Shares::WorkPackages::CreateContract"

    config.to_prepare do
      Principals::ReplaceReferencesService.add_replacements("DataPrivacy::Consent" => :author_id)
    end

    add_cron_jobs do
      {
        "DataPrivacy::AuditCleanupJob": {
          cron: "17 3 * * *",
          class: "DataPrivacy::AuditCleanupJob"
        }
      }
    end
  end
end
