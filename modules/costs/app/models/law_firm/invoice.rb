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
  class Invoice < ApplicationRecord
    self.table_name = "law_firm_invoices"

    belongs_to :project
    belongs_to :issued_by, class_name: "User", optional: true
    belongs_to :cancelled_by, class_name: "User", optional: true

    validates :serial, :number, presence: true, uniqueness: true
    validates :issued_on, :period_from, :period_to, :client_name, :client_address, presence: true
    validates :cancellation_reason, presence: true, if: :cancelled?

    scope :active, -> { where(cancelled_at: nil) }
    scope :newest_first, -> { order(serial: :desc) }

    before_update :prevent_changes_to_issued_content

    IMMUTABLE_ATTRIBUTES = %w[
      project_id serial number issued_on period_from period_to client_name client_address client_tin
      vatable_sales vat_exempt_sales zero_rated_sales vat_rate vat_amount total_amount
      ewt_base ewt_rate ewt_amount amount_due lines details seller time_entry_ids cost_entry_ids issued_by_id
    ].freeze

    def self.invoiced_entry_ids(project, column)
      active.where(project:).pluck(column).flatten
    end

    def cancelled?
      cancelled_at.present?
    end

    def reprint?
      first_printed_at.present?
    end

    def record_print!
      now = Time.current
      self.class.where(id:).update_all(["print_count = print_count + 1, first_printed_at = COALESCE(first_printed_at, ?)", now])
      reload
    end

    def filename
      "#{seller.fetch('title', 'Invoice').parameterize}-#{number}.pdf"
    end

    private

    def prevent_changes_to_issued_content
      changed = changed_attribute_names_to_save & IMMUTABLE_ATTRIBUTES
      return if changed.empty?

      errors.add(:base, :invoice_issued)
      throw :abort
    end
  end
end
