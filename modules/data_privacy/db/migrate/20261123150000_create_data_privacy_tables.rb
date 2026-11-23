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

require Rails.root.join("db/migrate/migration_utils/permission_adder")

class CreateDataPrivacyTables < ActiveRecord::Migration[8.1]
  def up
    create_table :data_privacy_consents do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :data_subject, null: false
      t.string :subject_role, null: false, default: "client"
      t.date :consent_given_on, null: false
      t.text :scope, null: false
      t.boolean :sensitive_personal_information, null: false, default: false
      t.text :notes
      t.date :withdrawn_on
      t.text :withdrawal_notes
      t.timestamps
    end

    # No foreign keys: the trail has to outlive the users and matters it mentions.
    create_table :data_privacy_audit_events do |t|
      t.bigint :user_id, null: false
      t.string :user_name, null: false
      t.bigint :project_id
      t.string :project_name
      t.string :resource_type
      t.bigint :resource_id
      t.string :action, null: false
      t.string :description
      t.string :http_method, null: false
      t.string :path, limit: 2000
      t.string :remote_ip
      t.string :user_agent, limit: 500
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :data_privacy_audit_events, :created_at
    add_index :data_privacy_audit_events, %i[user_id created_at]
    add_index :data_privacy_audit_events, %i[project_id created_at]
    add_index :data_privacy_audit_events, %i[resource_type resource_id]

    add_column :projects, :confidential, :boolean, null: false, default: false

    ::Migration::MigrationUtils::PermissionAdder.add(:edit_work_packages, :view_data_privacy_consents)
    ::Migration::MigrationUtils::PermissionAdder.add(:edit_work_packages, :manage_data_privacy_consents)
  end

  def down
    remove_column :projects, :confidential
    drop_table :data_privacy_audit_events
    drop_table :data_privacy_consents
    execute <<~SQL.squish
      DELETE FROM role_permissions
      WHERE permission IN ('view_data_privacy_consents', 'manage_data_privacy_consents')
    SQL
  end
end
