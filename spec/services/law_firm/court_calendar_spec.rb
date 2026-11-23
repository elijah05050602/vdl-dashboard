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

RSpec.describe LawFirm::CourtCalendar, with_settings: { start_of_week: 1, working_days: [1, 2, 3, 4, 5] } do
  shared_let(:hearing_type) { create(:type, name: "Hearing", is_milestone: true) }
  shared_let(:deadline_type) { create(:type, name: "Court deadline", is_milestone: true) }
  shared_let(:matter) { create(:project, name: "People v. Cruz", types: [hearing_type, deadline_type]) }
  shared_let(:other_matter) { create(:project, name: "Private matter", types: [hearing_type]) }

  shared_let(:lawyer) do
    create(:user, firstname: "Ana", lastname: "Reyes", member_with_permissions: { matter => %i[view_work_packages] })
  end
  shared_let(:associate) do
    create(:user, firstname: "Ben", lastname: "Santos", member_with_permissions: { matter => %i[view_work_packages] })
  end
  shared_let(:user) { create(:user, member_with_permissions: { matter => %i[view_work_packages] }) }

  shared_let(:time_field) { create(:list_wp_custom_field, name: "Hearing time", possible_values: ["8:30 AM", "1:30 PM"]) }
  shared_let(:kind_field) { create(:list_wp_custom_field, name: "Hearing kind", possible_values: ["Pre-trial", "Trial"]) }
  shared_let(:court_field) do
    create(:list_wp_custom_field, name: "Court", possible_values: ["Regional Trial Court", "Court of Appeals"])
  end
  shared_let(:branch_field) { create(:string_wp_custom_field, name: "Branch and station") }
  shared_let(:judge_field) { create(:string_wp_custom_field, name: "Presiding judge") }
  shared_let(:lawyer_field) { create(:user_wp_custom_field, name: "Appearing lawyer") }

  shared_let(:afternoon_trial) do
    create(:work_package, project: matter, type: hearing_type, subject: "Trial: prosecution evidence",
                          start_date: Date.new(2026, 11, 10), due_date: Date.new(2026, 11, 10))
  end
  shared_let(:morning_pretrial) do
    create(:work_package, project: matter, type: hearing_type, subject: "Pre-trial", assigned_to: associate,
                          start_date: Date.new(2026, 11, 10), due_date: Date.new(2026, 11, 10))
  end
  shared_let(:untimed_hearing) do
    create(:work_package, project: matter, type: hearing_type, subject: "Motion hearing",
                          start_date: Date.new(2026, 11, 10), due_date: Date.new(2026, 11, 10))
  end
  shared_let(:december_hearing) do
    create(:work_package, project: matter, type: hearing_type, subject: "Promulgation",
                          start_date: Date.new(2026, 12, 21), due_date: Date.new(2026, 12, 21))
  end
  shared_let(:hidden_hearing) do
    create(:work_package, project: other_matter, type: hearing_type, subject: "Hidden hearing",
                          start_date: Date.new(2026, 11, 10), due_date: Date.new(2026, 11, 10))
  end
  shared_let(:deadline) do
    create(:work_package, project: matter, type: deadline_type, subject: "File answer",
                          start_date: Date.new(2026, 11, 10), due_date: Date.new(2026, 11, 10))
  end

  def option(field, value)
    field.custom_options.find_by!(value:).id.to_s
  end

  before_all do
    rows = {
      afternoon_trial => { time_field => option(time_field, "1:30 PM"), kind_field => option(kind_field, "Trial"),
                           court_field => option(court_field, "Regional Trial Court"),
                           branch_field => "Branch 143, Makati City", judge_field => "Dela Cruz",
                           lawyer_field => lawyer.id.to_s },
      morning_pretrial => { time_field => option(time_field, "8:30 AM"), kind_field => option(kind_field, "Pre-trial"),
                            court_field => option(court_field, "Court of Appeals") },
      hidden_hearing => { time_field => option(time_field, "8:30 AM"), lawyer_field => lawyer.id.to_s }
    }.flat_map do |work_package, field_values|
      field_values.map do |field, value|
        { custom_field_id: field.id, customized_type: "WorkPackage", customized_id: work_package.id, value: }
      end
    end
    CustomValue.insert_all!(rows)
  end

  let(:params) { {} }

  subject(:calendar) { described_class.new(user:, date: "2026-11-18", **params) }

  describe "month view" do
    it "spans whole weeks around the month, starting on the configured weekday" do
      expect(calendar.view).to eq("month")
      expect(calendar.days).to eq(Date.new(2026, 10, 26)..Date.new(2026, 12, 6))
      expect(calendar.weeks.map(&:size).uniq).to eq([7])
    end

    it "lists the visible hearings of the period by time, untimed ones last" do
      expect(calendar.entries.map(&:work_package)).to eq([morning_pretrial, afternoon_trial, untimed_hearing])
      expect(calendar.entries_on(Date.new(2026, 11, 10)).size).to eq(3)
      expect(calendar.entries_on(Date.new(2026, 11, 11))).to be_empty
    end

    it "reads the hearing details", :aggregate_failures do
      entry = calendar.entries.find { it.work_package == afternoon_trial }

      expect(entry).to have_attributes(date: Date.new(2026, 11, 10), time: "1:30 PM", kind: "Trial",
                                       court: "Regional Trial Court", branch: "Branch 143, Makati City",
                                       judge: "Dela Cruz", lawyer:)
    end

    it "falls back to the assignee as the lawyer" do
      expect(calendar.entries.find { it.work_package == morning_pretrial }.lawyer).to eq(associate)
    end

    it "moves by month" do
      expect([calendar.previous_date, calendar.next_date]).to eq([Date.new(2026, 10, 1), Date.new(2026, 12, 1)])
    end
  end

  describe "week view" do
    let(:params) { { view: "week" } }

    it "covers the week of the date" do
      expect(calendar.days).to eq(Date.new(2026, 11, 16)..Date.new(2026, 11, 22))
      expect(calendar.entries).to be_empty
      expect([calendar.previous_date, calendar.next_date]).to eq([Date.new(2026, 11, 11), Date.new(2026, 11, 25)])
    end
  end

  describe "day view" do
    subject(:calendar) { described_class.new(user:, view: "day", date: "2026-11-10") }

    it "covers the day" do
      expect(calendar.days).to eq(Date.new(2026, 11, 10)..Date.new(2026, 11, 10))
      expect(calendar.entries.size).to eq(3)
    end
  end

  describe "filters" do
    it "filters by appearing lawyer" do
      calendar = described_class.new(user:, date: "2026-11-18", lawyer_id: lawyer.id.to_s)
      expect(calendar.entries.map(&:work_package)).to eq([afternoon_trial])
    end

    it "filters by assignee when no appearing lawyer is set" do
      calendar = described_class.new(user:, date: "2026-11-18", lawyer_id: associate.id.to_s)
      expect(calendar.entries.map(&:work_package)).to eq([morning_pretrial])
    end

    it "filters by court" do
      calendar = described_class.new(user:, date: "2026-11-18", court_id: option(court_field, "Court of Appeals"))
      expect(calendar.entries.map(&:work_package)).to eq([morning_pretrial])
    end

    it "offers the lawyers on visible hearings and the user" do
      expect(calendar.lawyer_options).to contain_exactly(lawyer, associate, user)
    end

    it "offers the courts in their order" do
      expect(calendar.court_options.map(&:value)).to eq(["Regional Trial Court", "Court of Appeals"])
    end
  end

  describe "non-working days" do
    before { create(:non_working_day, date: Date.new(2026, 11, 30), name: "Bonifacio Day") }

    it "names holidays and treats them and weekends as non-working", :aggregate_failures do
      expect(calendar.holiday_name(Date.new(2026, 11, 30))).to eq("Bonifacio Day")
      expect(calendar.working_day?(Date.new(2026, 11, 30))).to be(false)
      expect(calendar.working_day?(Date.new(2026, 11, 28))).to be(false)
      expect(calendar.working_day?(Date.new(2026, 11, 27))).to be(true)
    end
  end

  describe "invalid input" do
    subject(:calendar) { described_class.new(user:, view: "year", date: "not-a-date") }

    it "falls back to this month" do
      expect(calendar.view).to eq("month")
      expect(calendar.date).to eq(user.today)
    end
  end

  context "without a Hearing type" do
    before { hearing_type.update_column(:name, "Court hearing") }

    it "shows nothing" do
      expect(calendar).not_to be_configured
      expect(calendar.entries).to be_empty
      expect(calendar.lawyer_options).to be_empty
    end
  end
end
