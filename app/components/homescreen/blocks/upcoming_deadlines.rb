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
    class UpcomingDeadlines < Grids::WidgetComponent
      LIMIT = 8
      private_constant :LIMIT

      def title
        t("law_firm.deadlines.widget.title")
      end

      def render?
        current_user.logged? && LawFirm::Deadlines.types.exists?
      end

      def deadlines
        @deadlines ||= LawFirm::Deadlines.due_soon_or_overdue(user: current_user).limit(LIMIT).to_a
      end

      def today
        @today ||= Time.zone.today
      end

      def overdue?(work_package)
        work_package.due_date < today
      end

      def date_label(work_package)
        days = (work_package.due_date - today).to_i

        if days.negative?
          t("law_firm.deadlines.widget.overdue_by", count: -days)
        elsif days.zero?
          t("law_firm.deadlines.widget.today")
        else
          t("law_firm.deadlines.widget.in_days", count: days)
        end
      end

      def date_scheme(work_package)
        days = (work_package.due_date - today).to_i

        if days.negative?
          :danger
        elsif days <= 2
          :attention
        else
          :secondary
        end
      end

      def query_link(query_key)
        params = WorkPackages::DefaultQueryGeneratorService.new(with_project: nil).call(query_key:)
        work_packages_path(params.except(:show_enterprise_icon)) if params
      end
    end
  end
end
