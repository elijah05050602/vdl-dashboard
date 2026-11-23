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
  module BillingHelper
    def peso(amount)
      "₱ #{number_with_precision(amount.to_d, precision: 2, delimiter: ',')}"
    end

    def law_firm_billing_tabs(project, selected)
      render(Primer::Alpha::UnderlineNav.new(label: t("law_firm_billing.menu"), mb: 3)) do |nav|
        { show: project_billing_path(project),
          unbilled: unbilled_project_billing_path(project),
          terms: terms_project_billing_path(project) }.each do |tab, href|
          nav.with_tab(selected: tab == selected, href:) { t("law_firm_billing.tabs.#{tab}") }
        end
      end
    end
  end
end
