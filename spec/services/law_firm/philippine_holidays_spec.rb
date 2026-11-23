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

RSpec.describe LawFirm::PhilippineHolidays do
  subject(:holidays) { described_class.new(2026) }

  it "lists the 2026 holidays, including Holy Week and National Heroes Day" do
    expect(holidays.to_h).to include(
      Date.new(2026, 1, 1) => "New Year's Day",
      Date.new(2026, 4, 2) => "Maundy Thursday",
      Date.new(2026, 4, 3) => "Good Friday",
      Date.new(2026, 4, 4) => "Black Saturday",
      Date.new(2026, 6, 12) => "Independence Day",
      Date.new(2026, 8, 31) => "National Heroes Day",
      Date.new(2026, 12, 30) => "Rizal Day"
    )
    expect(holidays.to_h.size).to eq(17)
  end

  it "computes Easter for other years" do
    expect(described_class.new(2027).to_h).to include(Date.new(2027, 3, 26) => "Good Friday")
  end

  it "creates the missing non-working days only" do
    create(:non_working_day, date: Date.new(2026, 12, 25), name: "Christmas")

    expect { holidays.create_non_working_days }.to change(NonWorkingDay, :count).by(16)
    expect { holidays.create_non_working_days }.not_to change(NonWorkingDay, :count)
  end
end
