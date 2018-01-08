# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  layout :resolve_layout
  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  def new
    @title = 'ReputeSales :: User Registration'
    super
  end

  # POST /resource
  def create
    build_resource(configure_sign_up_params)
    if resource.save
      if session['plan'].present?
        session['plan_' + resource.id.to_s] = session['plan']
        session.delete('plan')
      end
      success_response(resource)
    else
      error_response(resource)
    end
  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  def update
    resource_updated = update_resource(resource, update_params)
    if resource_updated
      flash[:notice] = 'Your account has been updated successfully.'
      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
      redirect_to account_business_index_path
    else
      render :edit
    end
  end

  private

  def configure_sign_up_params
    params.require(:user).permit(:first_name, :last_name, :email, :password,
                                 :password_confirmation, :company_name, :country)
  end

  def update_params
     devise_parameter_sanitizer.sanitize(:account_update)
  end

  def success_response(resource)
    sign_up(resource_name, resource)
    respond_with resource, location: after_sign_in_path_for(resource)
  end

  def error_response(resource)
    flash[:alert] = resource.errors.full_messages.join(', ')
    respond_with resource, location: new_user_registration_path
  end

  def resolve_layout
    case action_name
    when 'update', 'edit'
      'business'
    else
      'devise'
    end
  end
end
