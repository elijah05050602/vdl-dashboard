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
require "open_project/law_firm/navigation"

module OpenProject::LawFirm
  class Engine < ::Rails::Engine
    engine_name :openproject_law_firm

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-law_firm",
             author_url: "https://github.com/elijah05050602/vdl-dashboard",
             bundled: true

    # Appended to config.i18n.load_path, which Rails loads after every
    # engine's config/locales, so these overrides win. Upstream specs expect
    # the stock wording, so it stays off in the test environment.
    initializer "openproject_law_firm.matter_terminology" do |app|
      unless Rails.env.test? || ENV["OPENPROJECT_LAW_FIRM_MATTER_TERMINOLOGY"] == "false"
        app.config.i18n.load_path << config.root.join("config/matter_terminology/en.yml").to_s
      end
    end

    # Upstream specs expect the stock menu and home page, so this stays off in
    # the test environment.
    config.after_initialize do
      if OpenProject::LawFirm::Navigation.enabled?
        OpenProject::LawFirm::Navigation.apply!
        OpenProject::LawFirm::Navigation.simplify_homescreen!
      end
    end
  end
end
