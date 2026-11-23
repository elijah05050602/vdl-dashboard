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

RSpec.describe LawFirm::DeadlineDigestJob do
  shared_let(:court_deadline) { create(:type, name: "Court deadline") }
  shared_let(:project) { create(:project, types: [court_deadline]) }
  shared_let(:user) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }

  context "with an upcoming deadline" do
    let!(:work_package) do
      create(:work_package,
             project:,
             type: court_deadline,
             assigned_to: user,
             start_date: nil,
             due_date: Date.current + 3.days)
    end

    it "emails the digest" do
      expect { described_class.perform_now(user) }
        .to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([user.mail])
      expect(mail.subject).to include("1 deadline needs your attention")
      expect(mail.html_part.body.to_s).to include(work_package.subject)
      expect(mail.text_part.body.to_s).to include(work_package.subject)
    end

    it "does not email users who turned off daily email reminders" do
      user.pref.update!(daily_reminders: { enabled: false, times: [] })

      expect { described_class.perform_now(user) }
        .not_to change { ActionMailer::Base.deliveries.size }
    end
  end

  it "does not email when there are no deadlines" do
    expect { described_class.perform_now(user) }
      .not_to change { ActionMailer::Base.deliveries.size }
  end
end
