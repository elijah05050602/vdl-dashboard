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
  # Firm-wide aging of what clients owe, across the matters the user may see.
  class ReceivablesController < ApplicationController
    menu_item :law_firm_receivables
    helper LawFirm::BillingHelper

    before_action :require_login
    before_action :authorize_receivables
    authorization_checked! :index

    def index
      projects = Project.allowed_to(User.current, :view_law_firm_receivables)
      receivables = Receivable.for_projects(projects)

      @open = receivables.select(&:open?).sort_by(&:due_on)
      @by_bucket = @open.group_by(&:bucket)
      @missing_certificates = receivables.select(&:certificate_missing?)
    end

    private

    def authorize_receivables
      render_403 unless User.current.allowed_in_any_project?(:view_law_firm_receivables)
    end
  end
end
