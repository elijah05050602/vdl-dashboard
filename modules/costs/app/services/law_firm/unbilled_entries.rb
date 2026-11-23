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
  # Time and costs logged on a matter that no issued invoice covers yet.
  class UnbilledEntries
    def initialize(project)
      @project = project
    end

    def time_entries
      @time_entries ||= TimeEntry
        .where(project: @project, ongoing: false)
        .where.not(id: Invoice.invoiced_entry_ids(@project, :time_entry_ids))
        .includes(:user, :activity, :entity)
        .order(:spent_on, :id)
        .to_a
    end

    def cost_entries
      @cost_entries ||= CostEntry
        .where(project: @project)
        .where.not(id: Invoice.invoiced_entry_ids(@project, :cost_entry_ids))
        .includes(:user, :cost_type)
        .order(:spent_on, :id)
        .to_a
    end

    def include?(entry)
      (entry.is_a?(TimeEntry) ? time_entries : cost_entries).include?(entry)
    end

    def total
      (time_entries + cost_entries).sum(0.to_d) { |entry| entry.real_costs.to_d }
    end

    def hours
      time_entries.sum(0.to_d) { |entry| entry.hours.to_d }
    end
  end
end
