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


# Law firm customization: English UI says "matter" instead of "project".
# Loaded after every other locale file so it wins. Upstream specs expect the
# stock wording, so it stays off in the test environment.
# Set OPENPROJECT_LAW_FIRM_MATTER_TERMINOLOGY=false to turn it off.
unless Rails.env.test? || ENV["OPENPROJECT_LAW_FIRM_MATTER_TERMINOLOGY"] == "false"
  Rails.application.config.i18n.load_path << Rails.root.join("config/law_firm/locales/en.matter_terminology.yml").to_s
end
