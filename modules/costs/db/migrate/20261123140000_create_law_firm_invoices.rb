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

class CreateLawFirmInvoices < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/AbcSize
    create_table :law_firm_invoices do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :serial, null: false
      t.string :number, null: false
      t.date :issued_on, null: false
      t.date :period_from, null: false
      t.date :period_to, null: false

      t.string :client_name, null: false
      t.text :client_address, null: false
      t.string :client_tin

      t.decimal :vatable_sales, precision: 15, scale: 2, null: false, default: 0
      t.decimal :vat_exempt_sales, precision: 15, scale: 2, null: false, default: 0
      t.decimal :zero_rated_sales, precision: 15, scale: 2, null: false, default: 0
      t.decimal :vat_rate, precision: 5, scale: 4
      t.decimal :vat_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :total_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :ewt_base, precision: 15, scale: 2, null: false, default: 0
      t.decimal :ewt_rate, precision: 5, scale: 4
      t.decimal :ewt_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :amount_due, precision: 15, scale: 2, null: false, default: 0

      t.jsonb :lines, null: false, default: []
      t.jsonb :details, null: false, default: []
      t.jsonb :seller, null: false, default: {}
      t.bigint :time_entry_ids, array: true, null: false, default: []
      t.bigint :cost_entry_ids, array: true, null: false, default: []

      t.references :issued_by
      t.datetime :first_printed_at
      t.integer :print_count, null: false, default: 0
      t.datetime :cancelled_at
      t.references :cancelled_by
      t.text :cancellation_reason

      t.timestamps
    end

    add_index :law_firm_invoices, :serial, unique: true
    add_index :law_firm_invoices, :number, unique: true
  end
end
