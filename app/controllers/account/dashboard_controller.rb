# frozen_string_literal: true

module Account
  #:nodoc:
  class DashboardController < BaseController
    before_action :authenticate_user!, only: :index
    def index; end

    def user_plan
      session['plan'] = params[:plan]
      redirect_to new_user_registration_path
    end
  end
end
