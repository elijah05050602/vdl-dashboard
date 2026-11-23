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
  module Receivables
    # Lowers what an unbilled time or cost entry bills for, keeping a record of
    # who did it, why and what it was before. Issued invoices cannot change, so
    # only entries no invoice covers yet can be written down.
    class WriteDownService
      def initialize(user:, project:)
        @user = user
        @project = project
      end

      def call(entry:, new_amount:, reason:)
        write_down = WriteDown.new(project:, entry:, user:, reason:, original_amount: entry.real_costs.to_d,
                                   new_amount: parse(new_amount))
        error = check(write_down)
        return failure(write_down, error) if error

        WriteDown.transaction do
          write_down.save!
          entry.update_columns(overridden_costs: write_down.new_amount, updated_at: Time.current)
        end

        ServiceResult.success(result: write_down)
      end

      private

      attr_reader :user, :project

      def check(write_down)
        return :not_unbilled unless UnbilledEntries.new(project).include?(write_down.entry)
        return :invalid unless write_down.valid?

        :not_lower unless write_down.new_amount < write_down.original_amount
      end

      def parse(value)
        BigDecimal(value.to_s.delete(","))
      rescue ArgumentError
        nil
      end

      def failure(write_down, error)
        write_down.errors.add(:new_amount, error) unless error == :invalid
        ServiceResult.failure(result: write_down, errors: write_down.errors)
      end
    end
  end
end
