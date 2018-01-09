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

    # POST /resource/sign_in
    def create
      resource = User.find_for_database_authentication(email: users_params[:email])
      if resource.present?
        if resource.active
          super
        else
          flash[:alert] = 'account is not active!!!'
          redirect_to new_user_session_path
        end
      else
        flash[:alert] = 'User Not Found!'
        redirect_to new_user_session_path
      end
    end

    # DELETE /resource/sign_out
    # def destroy
    #   super
    # end

    # protected

    # If you have extra params to permit, append them to the sanitizer.
    # def configure_sign_in_params
    #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
    # end
    protected

    # If you have extra params to permit, append them to the sanitizer.
    def users_params
      params.require(:user).permit(:email, :password, :remember_me)
    end
  end
end
