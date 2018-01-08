# frozen_string_literal: true

module Users
  #:nodoc:
  class SessionsController < Devise::SessionsController
    # before_action :configure_sign_in_params, only: [:create]

    # GET /resource/sign_in
    def new
      @title = 'ReputeSales :: LOGIN'
      super
    end

  end
end
