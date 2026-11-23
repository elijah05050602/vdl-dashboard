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
  class AuditRecorder
    EXPORT_FORMATS = %i[csv xls xlsx pdf md docx atom ics].freeze
    EXPORT_ACTIONS = %w[generate_pdf export export_project_initiation_pdf].freeze
    RESOURCE_VARIABLES = %i[@consent @work_package @meeting @document @wiki_page @time_entry @version].freeze
    SIGN_IN_ACTIONS = %w[account#login two_factor_authentication/authentication#confirm_otp].freeze
    REPEAT_WINDOW = 1.minute

    API_PREFIX = %r{\A/api/v3/}
    API_VIEWS = {
      %r{\A/api/v3/work_packages/([^/]+)\z} => ["view", "WorkPackage"],
      %r{\A/api/v3/attachments/(\d+)/content\z} => ["download", "Attachment"]
    }.freeze
    API_RESOURCES = {
      "work_packages" => "WorkPackage",
      "projects" => "Project",
      "attachments" => "Attachment",
      "time_entries" => "TimeEntry",
      "versions" => "Version",
      "memberships" => "Member",
      "relations" => "Relation",
      "activities" => "Journal"
    }.freeze
    # Validation previews and read markers change nothing worth auditing.
    API_IGNORED_WRITES = %r{/form\z|\A/api/v3/render/|\A/api/v3/notifications|\A/api/v3/queries|\A/api/v3/my_preferences}

    attr_reader :request, :status

    def initialize(env, status)
      @request = ActionDispatch::Request.new(env)
      @status = status.to_i
    end

    def call
      return unless status < 400

      user = User.current
      return unless user.logged?

      attributes = request.path_info.match?(API_PREFIX) ? api_event : rails_event
      return if attributes.nil? || repeated?(user, attributes)

      AuditEvent.create!(attributes.merge(common_attributes(user)))
    end

    private

    def rails_event
      controller = request.controller_instance
      return if controller.nil?

      name = "#{controller.controller_path}##{controller.action_name}"
      resource = controller_resource(controller)
      project = controller_project(controller, resource)
      action = rails_action(controller, name, project, resource)
      return if action.nil?

      { action:, project:, resource:, description: name }
    end

    def rails_action(controller, name, project, resource)
      if SIGN_IN_ACTIONS.include?(name) && !request.get?
        "sign_in"
      elsif !read_request?
        "change"
      elsif export_request?(controller)
        "export"
      elsif (project || resource) && page_view?
        "view"
      end
    end

    def export_request?(controller)
      EXPORT_ACTIONS.include?(controller.action_name) || EXPORT_FORMATS.include?(request.format&.symbol)
    end

    def page_view?
      request.format&.html? && !request.xhr? && request.headers["Turbo-Frame"].blank?
    end

    def controller_resource(controller)
      RESOURCE_VARIABLES.each do |variable|
        value = controller.instance_variable_get(variable) if controller.instance_variable_defined?(variable)
        return value if value.is_a?(ApplicationRecord) && value.persisted?
      end

      nil
    end

    def controller_project(controller, resource)
      project = controller.instance_variable_get(:@project) if controller.instance_variable_defined?(:@project)
      project = nil unless project.is_a?(Project) && project.persisted?
      project || project_of(resource)
    end

    def api_event
      path = request.path_info.chomp("/")

      if read_request?
        api_view(path)
      elsif !path.match?(API_IGNORED_WRITES)
        api_change(path)
      end
    end

    def api_view(path)
      API_VIEWS.each do |pattern, (action, class_name)|
        match = pattern.match(path)
        next unless match

        resource = find_resource(class_name, match[1])
        return nil if resource.nil?

        return { action:, resource:, project: project_of(resource), description: "API #{request.request_method} #{path}" }
      end

      nil
    end

    def api_change(path)
      segments = path.delete_prefix("/api/v3/").split("/")
      class_name = API_RESOURCES[segments[0]]
      resource = find_resource(class_name, segments[1]) if class_name && segments[1].present?

      { action: "change", resource:, project: project_of(resource),
        description: "API #{request.request_method} #{path}" }
    end

    def find_resource(class_name, id)
      klass = class_name.constantize
      if klass == WorkPackage
        WorkPackage.find_by_display_id(id)
      elsif id.to_s.match?(/\A\d+\z/)
        klass.find_by(id:)
      end
    end

    def project_of(resource)
      return resource if resource.is_a?(Project)
      return project_of(resource.container) if resource.is_a?(Attachment) && resource.container
      return project_of(resource.journable) if resource.is_a?(Journal)

      project = resource.project if resource.respond_to?(:project)
      project if project.is_a?(Project)
    end

    def read_request?
      request.get? || request.head?
    end

    def repeated?(user, attributes)
      return false unless %w[view download].include?(attributes[:action])

      key = ["audit_trail", user.id, attributes[:action], attributes[:resource]&.class&.name,
             attributes[:resource]&.id, attributes[:project]&.id, attributes[:description]].join("/")
      !Rails.cache.write(key, true, expires_in: REPEAT_WINDOW, unless_exist: true)
    end

    def common_attributes(user)
      {
        user:,
        http_method: request.request_method,
        path: request.fullpath.truncate(AuditEvent::PATH_LIMIT, omission: ""),
        remote_ip: request.remote_ip,
        user_agent: request.user_agent.to_s.truncate(AuditEvent::USER_AGENT_LIMIT, omission: "")
      }
    end
  end
end
