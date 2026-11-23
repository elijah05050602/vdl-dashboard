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

module DataPrivacy
  class AuditEvent < ApplicationRecord
    self.table_name = "data_privacy_audit_events"

    ACTIONS = %w[view change export download sign_in].freeze
    PATH_LIMIT = 2000
    USER_AGENT_LIMIT = 500

    belongs_to :user, class_name: "Principal", optional: true
    belongs_to :project, optional: true
    belongs_to :resource, polymorphic: true, optional: true

    validates :action, inclusion: { in: ACTIONS }
    validates :user_id, :user_name, presence: true

    before_validation :snapshot_names, on: :create

    scope :newest_first, -> { order(created_at: :desc, id: :desc) }
    scope :older_than, ->(time) { where(created_at: ...time) }

    def readonly?
      persisted?
    end

    def user_label
      user&.name || user_name
    end

    def project_label
      project&.name || project_name
    end

    def resource_label
      return if resource_type.nil?

      label = resource && (resource.try(:subject) || resource.try(:data_subject) || resource.try(:name) || resource.try(:filename))
      [resource_type.demodulize.titleize, "##{resource_id}", label].compact.join(" ")
    end

    private

    def snapshot_names
      self.user_name ||= user&.name
      self.project_name ||= project&.name
    end
  end
end
