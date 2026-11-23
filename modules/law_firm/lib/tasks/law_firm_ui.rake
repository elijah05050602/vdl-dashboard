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

namespace :law_firm do
  desc "Create the VDL Firm matter, its firm board and the firm welcome text"
  task setup_firm: :environment do
    admin = User.admin.active.first || raise("No active administrator found")
    result = LawFirm::FirmSetup.new(user: admin).call
    puts "Firm board ready: #{result.result.name} in #{result.result.project.name}"
  end

  desc "Remove the OpenProject demo and developer sample projects and lock their sample users"
  task remove_sample_data: :environment do
    admin = User.admin.active.first || raise("No active administrator found")
    result = LawFirm::SampleDataCleanup.new(user: admin).call.result

    puts "Removed projects: #{result[:removed_projects].presence&.join(', ') || 'none'}"
    puts "Locked sample users: #{result[:locked_users].presence&.join(', ') || 'none'}"
  end
end
