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
  class ConsentsController < ::ApplicationController
    before_action :find_project_by_project_id
    before_action :authorize, except: %i[destroy confidential]
    before_action :require_admin, only: %i[destroy confidential]
    before_action :find_consent, only: %i[edit update edit_withdrawal withdraw destroy]

    menu_item :data_privacy

    def index
      @consents = @project.data_privacy_consents.includes(:author, :attachments).by_subject
    end

    def new
      @consent = @project.data_privacy_consents.build(consent_given_on: Time.zone.today, subject_role: "client")
    end

    def edit; end

    def edit_withdrawal
      @consent.withdrawn_on ||= Time.zone.today
    end

    def create
      @consent = @project.data_privacy_consents.build(consent_params.merge(author: current_user))
      save_with_document(:new, I18n.t(:notice_successful_create))
    end

    def update
      @consent.assign_attributes(consent_params)
      save_with_document(:edit, I18n.t(:notice_successful_update))
    end

    def withdraw
      @consent.assign_attributes(withdrawal_params)
      @consent.errors.add(:withdrawn_on, :blank) if @consent.withdrawn_on.nil?

      if @consent.errors.none? && @consent.save
        redirect_to project_data_privacy_consents_path(@project), notice: I18n.t("data_privacy.consents.withdrawn_notice")
      else
        render :edit_withdrawal, status: :unprocessable_entity
      end
    end

    def destroy
      @consent.destroy!
      redirect_to project_data_privacy_consents_path(@project), notice: I18n.t(:notice_successful_delete), status: :see_other
    end

    def confidential
      confidential = params.require(:confidential).to_s == "true"
      attributes = confidential ? { confidential: true, public: false } : { confidential: false }
      result = Projects::UpdateService.new(user: current_user, model: @project).call(attributes)

      if result.success?
        flash[:notice] = I18n.t("data_privacy.confidential.#{confidential ? 'marked' : 'lifted'}")
      else
        flash[:error] = result.errors.full_messages.to_sentence
      end
      redirect_to project_data_privacy_consents_path(@project), status: :see_other
    end

    private

    def find_consent
      @consent = @project.data_privacy_consents.find(params[:id])
    end

    def consent_params
      params.require(:consent).permit(:data_subject, :subject_role, :consent_given_on, :scope,
                                      :sensitive_personal_information, :notes)
    end

    def withdrawal_params
      params.require(:consent).permit(:withdrawn_on, :withdrawal_notes)
    end

    def document
      params.dig(:consent, :document).presence
    end

    def save_with_document(failure_template, notice)
      saved = Consent.transaction do
        @consent.save && attach_document || raise(ActiveRecord::Rollback)
      end

      if saved
        redirect_to project_data_privacy_consents_path(@project), notice:
      else
        render failure_template, status: :unprocessable_entity
      end
    end

    def attach_document
      return true if document.nil?

      result = Attachments::CreateService
                 .new(user: current_user)
                 .call(container: @consent, filename: document.original_filename, file: document)
      return true if result.success?

      document_error(result.message.presence || result.errors.full_messages.to_sentence)
    rescue RuntimeError => e
      document_error(e.message)
    end

    def document_error(message)
      @consent.errors.add(:base, message)
      false
    end
  end
end
