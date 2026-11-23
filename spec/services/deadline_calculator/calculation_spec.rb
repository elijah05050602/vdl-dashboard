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

RSpec.describe DeadlineCalculator::Calculation do
  subject(:calculation) { described_class.new(received_on: Date.new(*received_on), period:) }

  let(:period) { DeadlineCalculator::Period.find("notice_of_appeal") }

  before do
    week_with_saturday_and_sunday_as_weekend
    create(:non_working_day, date: Date.new(2026, 11, 30), name: "Bonifacio Day")
  end

  context "when the last day is a working day" do
    let(:received_on) { [2026, 11, 23] }

    it "excludes the day of receipt and includes the last day" do
      expect([calculation.last_day, calculation.due_on, calculation.moved?])
        .to eq([Date.new(2026, 12, 8), Date.new(2026, 12, 8), false])
    end
  end

  context "when the last day is a Saturday" do
    let(:received_on) { [2026, 11, 20] }

    it "moves to the Monday" do
      expect(calculation.last_day).to eq(Date.new(2026, 12, 5))
      expect(calculation.due_on).to eq(Date.new(2026, 12, 7))
      expect(calculation.skipped_days.map(&:reason)).to eq(%w[Saturday Sunday])
    end
  end

  context "when the last day is a holiday" do
    let(:received_on) { [2026, 11, 15] }

    it "moves to the next working day and names the holiday" do
      expect(calculation.due_on).to eq(Date.new(2026, 12, 1))
      expect(calculation.skipped_days.map(&:reason)).to eq(["Bonifacio Day"])
    end
  end

  context "when a weekend runs into a holiday" do
    let(:received_on) { [2026, 11, 13] }

    it "skips all of them" do
      expect(calculation.last_day).to eq(Date.new(2026, 11, 28))
      expect(calculation.due_on).to eq(Date.new(2026, 12, 1))
      expect(calculation.skipped_days.map(&:reason)).to eq(["Saturday", "Sunday", "Bonifacio Day"])
    end
  end

  context "with a 30-day period across a month end" do
    let(:period) { DeadlineCalculator::Period.find("answer") }
    let(:received_on) { [2027, 1, 29] }

    it "counts calendar days, not working days" do
      expect(calculation.last_day).to eq(Date.new(2027, 2, 28))
      expect(calculation.due_on).to eq(Date.new(2027, 3, 1))
    end
  end

  context "with an NLRC appeal" do
    let(:period) { DeadlineCalculator::Period.find("nlrc_appeal") }
    let(:received_on) { [2026, 11, 23] }

    it "uses 10 calendar days" do
      expect(calculation.due_on).to eq(Date.new(2026, 12, 3))
    end
  end
end
