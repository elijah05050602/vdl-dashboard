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

class CreateClientRegistry < ActiveRecord::Migration[8.1]
  def up
    create_tables
    grant_permissions
  end

  def down
    drop_table :matter_parties
    drop_table :party_aliases
    drop_table :parties
    RolePermission.where(permission: %w[view_client_registry manage_client_registry
                                        view_matter_parties manage_matter_parties]).delete_all
  end

  private

  def create_tables
    create_parties
    create_party_aliases
    create_matter_parties
  end

  def create_parties
    create_table :parties do |t|
      t.string :kind, null: false, default: "person"
      t.string :name, null: false
      t.string :tin
      t.string :email
      t.string :phone
      t.text :address
      t.text :notes
      t.references :author, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :parties, :name
    add_index :parties, :tin, unique: true, where: "tin IS NOT NULL"
  end

  def create_party_aliases
    create_table :party_aliases do |t|
      t.references :party, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :alias_type, null: false, default: "other_name"
      t.timestamps
    end
  end

  def create_matter_parties
    create_table :matter_parties do |t|
      t.references :project, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :party, null: false, foreign_key: true
      t.string :role, null: false
      t.text :notes
      t.timestamps
    end
    add_index :matter_parties, %i[project_id party_id role], unique: true
  end

  def grant_permissions
    GlobalRole.where(builtin: Role::BUILTIN_STANDARD_GLOBAL).find_each do |role|
      %i[view_client_registry manage_client_registry].each do |permission|
        role.add_permission!(permission) unless role.has_permission?(permission)
      end
    end

    ::Migration::MigrationUtils::PermissionAdder.add(:view_project_attributes, :view_matter_parties)
    ::Migration::MigrationUtils::PermissionAdder.add(:edit_project_attributes, :manage_matter_parties)
  end
end
