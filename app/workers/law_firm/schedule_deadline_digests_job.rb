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
  # Runs every 15 minutes and sends the deadline digest to users whose local time
  # has just reached Setting.deadline_digest_hour.
  class ScheduleDeadlineDigestsJob < ApplicationJob
    include Cron::QuarterHourScheduleJob

    queue_as :transactional

    def perform
      return unless Setting.deadline_digest_enabled?
      return if LawFirm::DeadlineDigest.deadline_types.none?

      recipients.find_each do |user|
        LawFirm::DeadlineDigestJob.perform_later(user)
      end
    end

    private

    def recipients
      User
        .active
        .with_time_zone(time_zones_at_digest_hour)
    end

    def time_zones_at_digest_hour
      UserPreferences::UpdateContract
        .assignable_time_zones
        .select { |time_zone| run_times.any? { |time| digest_time?(time, time_zone) } }
        .map { |time_zone| time_zone.tzinfo.canonical_zone.name }
        .uniq
    end

    def digest_time?(time, time_zone)
      local_time = time.in_time_zone(time_zone)
      local_time.hour == Setting.deadline_digest_hour.to_i && local_time.min.zero?
    end

    def run_times
      return [] if upper_boundary.blank?

      lower = lower_boundary || upper_boundary
      (lower.to_i..upper_boundary.to_i).step(15.minutes).map { |time| Time.zone.at(time) }
    end
  end
end
