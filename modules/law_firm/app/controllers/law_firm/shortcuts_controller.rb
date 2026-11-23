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
  class ShortcutsController < ::ApplicationController
    before_action :require_login
    no_authorization_required! :deadlines, :board

    def deadlines
      query_params = ::WorkPackages::DefaultQueryGeneratorService
        .new(with_project: nil)
        .call(query_key: :upcoming_deadlines)

      redirect_to work_packages_path(query_params&.except(:show_enterprise_icon) || {})
    end

    def board
      board = FirmSetup.board

      if board && FirmSetup.firm_project_visible?(current_user)
        redirect_to project_work_package_board_path(board.project, board)
      else
        flash[:info] = I18n.t("law_firm.navigation.firm_board_missing")
        redirect_to home_path
      end
    end
  end
end
