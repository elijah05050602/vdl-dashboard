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

class CreateLawFirmReceivables < ActiveRecord::Migration[8.1]
  def change
    create_law_firm_payments
    create_law_firm_withholding_certificates
    create_law_firm_retainer_entries
    create_law_firm_write_downs
    create_law_firm_engagement_terms
  end

  private

  def create_law_firm_payments
    create_table :law_firm_payments do |t|
      t.references :invoice, null: false, foreign_key: { to_table: :law_firm_invoices }
      t.date :received_on, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :payment_method, null: false
      t.string :reference
      t.text :note
      t.references :recorded_by
      t.timestamps
    end
  end

  def create_law_firm_withholding_certificates
    create_table :law_firm_withholding_certificates do |t|
      t.references :invoice, null: false, foreign_key: { to_table: :law_firm_invoices }
      t.date :received_on, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :period
      t.text :note
      t.references :recorded_by
      t.timestamps
    end
  end

  def create_law_firm_retainer_entries
    create_table :law_firm_retainer_entries do |t|
      t.references :project, null: false, foreign_key: true
      t.date :entry_on, null: false
      t.string :kind, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.references :payment, foreign_key: { to_table: :law_firm_payments, on_delete: :cascade }
      t.string :reference
      t.text :note
      t.references :recorded_by
      t.timestamps
    end
  end

  def create_law_firm_write_downs
    create_table :law_firm_write_downs do |t|
      t.references :project, null: false, foreign_key: true
      t.references :entry, polymorphic: true, null: false
      t.decimal :original_amount, precision: 15, scale: 2, null: false
      t.decimal :new_amount, precision: 15, scale: 2, null: false
      t.text :reason, null: false
      t.references :user
      t.timestamps
    end
  end

  def create_law_firm_engagement_terms
    create_table :law_firm_engagement_terms do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.boolean :withholds_ewt, null: false, default: false
      t.decimal :ewt_rate, precision: 5, scale: 4
      t.integer :payment_terms_days
      t.decimal :retainer_minimum, precision: 15, scale: 2
      t.jsonb :role_rates, null: false, default: {}
      t.timestamps
    end
  end
end
