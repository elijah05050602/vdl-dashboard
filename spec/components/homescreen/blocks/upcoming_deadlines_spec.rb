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

require "rails_helper"

RSpec.describe Homescreen::Blocks::UpcomingDeadlines, type: :component do
  include Rails.application.routes.url_helpers

  shared_let(:court_deadline) { create(:type, name: "Court deadline", is_milestone: true) }
  shared_let(:hearing) { create(:type, name: "Hearing", is_milestone: true) }
  shared_let(:task) { create(:type_task) }
  shared_let(:open_status) { create(:default_status) }
  shared_let(:closed_status) { create(:closed_status) }
  shared_let(:matter) { create(:project, name: "Smith v. Jones", types: [court_deadline, hearing, task]) }
  shared_let(:other_matter) { create(:project, name: "Secret matter", types: [court_deadline, hearing, task]) }
  shared_let(:user) { create(:user, member_with_permissions: { matter => %i[view_work_packages] }) }

  current_user { user }

  subject(:rendered_component) { render_inline(described_class.new) }

  def deadline(subject, due_in:, type: court_deadline, project: matter, status: open_status)
    due_date = Time.zone.today + due_in
    create(:work_package, subject:, type:, project:, status:, start_date: due_date, due_date:)
  end

  context "with no deadlines" do
    it "renders the empty state" do
      expect(rendered_component).to have_test_selector("upcoming-deadlines-widget-empty")
      expect(rendered_component).to have_text("Nothing due soon")
    end
  end

  context "with deadlines" do
    before do
      deadline("File answer", due_in: -3)
      deadline("Pretrial hearing", due_in: 0, type: hearing)
      deadline("Discovery cutoff", due_in: 10)
      deadline("Far away", due_in: 45)
      deadline("Already filed", due_in: 1, status: closed_status)
      deadline("Ordinary task", due_in: 1, type: task)
      deadline("Hidden matter deadline", due_in: 1, project: other_matter)
    end

    it "lists open deadlines and hearings due within 30 days, overdue first", :aggregate_failures do
      rows = Capybara.string(rendered_component.to_html).all("[data-test-selector='upcoming-deadlines-widget-row']")
      expect(rows.map { it.find("a").text }).to eq(["File answer", "Pretrial hearing", "Discovery cutoff"])

      expect(rows[0]).to have_text("Overdue by 3 days")
      expect(rows[0]).to have_css(".Label--danger")
      expect(rows[0]).to have_text("Court deadline · Smith v. Jones")
      expect(rows[1]).to have_text("Today")
      expect(rows[2]).to have_text("In 10 days")
    end

    it "links to the full lists" do
      expect(rendered_component).to have_link("All upcoming")
      expect(rendered_component).to have_link("All overdue")
    end
  end

  describe "#render?" do
    it "is hidden for anonymous users" do
      expect(described_class.new(current_user: User.anonymous)).not_to be_render
    end

    it "is hidden when the legal types do not exist" do
      Type.where(name: LawFirm::Deadlines::TYPE_NAMES).delete_all
      expect(described_class.new).not_to be_render
    end
  end
end
