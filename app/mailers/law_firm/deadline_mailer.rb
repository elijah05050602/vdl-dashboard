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
  class DeadlineMailer < ApplicationMailer
    include OpenProject::StaticRouting::UrlHelpers

    helper :mail_layout,
           :mail_notification

    def digest(user, digest)
      @user = user
      @digest = digest

      open_project_headers User: user.name
      message_id "deadline-digest", user

      send_localized_mail(user) do
        I18n.t("law_firm.deadline_digest.subject",
               app_title: Setting.app_title,
               count: (digest.reminders + digest.overdue).map { |entry| entry.work_package.id }.uniq.size)
      end
    end
  end
end
