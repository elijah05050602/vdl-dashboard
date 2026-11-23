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

require "spec_helper"

RSpec.describe LawFirm::DeadlineDigest do
  shared_let(:court_deadline) { create(:type, name: "Court deadline") }
  shared_let(:hearing) { create(:type, name: "Hearing") }
  shared_let(:task) { create(:type, name: "Task") }
  shared_let(:project) { create(:project, types: [court_deadline, hearing, task]) }
  shared_let(:hidden_project) { create(:project, types: [court_deadline]) }
  shared_let(:open_status) { create(:status) }
  shared_let(:closed_status) { create(:closed_status) }
  shared_let(:user) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }
  shared_let(:colleague) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }

  let(:today) { Date.new(2026, 11, 23) }

  subject(:digest) { described_class.new(user, today:) }

  def deadline(due_in:, type: court_deadline, assignee: user, status: open_status, in_project: project)
    create(:work_package,
           project: in_project,
           type:,
           status:,
           assigned_to: assignee,
           start_date: nil,
           due_date: today + due_in.days)
  end

  def work_packages(entries)
    entries.map(&:work_package)
  end

  describe "#reminders" do
    it "includes the user's deadlines on each reminder day and when overdue" do
      reminded = [14, 7, 3, 1, 0, -2].map { |days| deadline(due_in: days) }
      deadline(due_in: 5)
      deadline(due_in: 2)

      expect(work_packages(digest.reminders)).to eq(reminded.sort_by(&:due_date))
    end

    it "includes hearings but ignores other types, closed deadlines and other people's deadlines" do
      hearing_wp = deadline(due_in: 1, type: hearing)
      deadline(due_in: 1, type: task)
      deadline(due_in: 1, status: closed_status)
      deadline(due_in: 1, assignee: colleague)

      expect(work_packages(digest.reminders)).to eq([hearing_wp])
    end

    it "includes deadlines the user is accountable for" do
      wp = deadline(due_in: 7, assignee: colleague)
      wp.update_column(:responsible_id, user.id)

      expect(work_packages(digest.reminders)).to eq([wp])
    end

    it "uses the configured reminder days", with_settings: { deadline_reminder_days: [10] } do
      ten = deadline(due_in: 10)
      deadline(due_in: 7)

      expect(work_packages(digest.reminders)).to eq([ten])
    end
  end

  describe "#upcoming" do
    it "lists every visible open deadline of the firm within the window" do
      own = deadline(due_in: 2)
      colleagues = deadline(due_in: 10, assignee: colleague)
      deadline(due_in: 15)
      deadline(due_in: -1)
      deadline(due_in: 3, in_project: hidden_project, assignee: nil)

      expect(work_packages(digest.upcoming)).to eq([own, colleagues])
      expect(digest.upcoming.map(&:days_left)).to eq([2, 10])
    end
  end

  describe "#overdue" do
    it "lists every visible overdue deadline of the firm" do
      overdue = deadline(due_in: -3, assignee: colleague)
      deadline(due_in: 0)

      expect(work_packages(digest.overdue)).to eq([overdue])
      expect(digest.overdue.first).to be_overdue
    end
  end

  describe "#empty?" do
    it "is true without deadlines" do
      deadline(due_in: 30)

      expect(digest).to be_empty
    end
  end
end
