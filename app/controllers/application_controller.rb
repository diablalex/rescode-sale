# frozen_string_literal: true

class ApplicationController < ActionController::Base
  layout :layout_by_resource
  before_action :configure_permitted_parameters, if: :devise_controller?

  # After sign-in path for resource
  def after_sign_in_path_for(resource)
    if resource.class == Partner && current_partner
      partners_dashboard_index_path
    elsif resource.class == User && current_user
      if current_user.businesses.present?
        account_business_index_path
      else
        new_account_business_path
      end
    elsif resource.class == PartnerUser && current_partners_partner_user
      partners_partner_users_business_index_path
    elsif resource.class == Admin && current_admin
      admins_dashboard_index_path
    elsif resource.class == InternalUser && current_internal_user
      stored_location_for(resource) || internal_users_dashboard_index_path
    else
      super
    end
  end

  # After sign-out path for resource
  def after_sign_out_path_for(resource)
    if resource.to_s == 'user'
      new_user_session_path
    elsif resource.to_s == 'partner'
      new_partner_session_path
    elsif resource.to_s == 'partners_partner_user'
      new_partners_partner_user_session_path(slug: params[:slug])
    elsif resource.to_s == 'admin'
      new_admin_session_path
    elsif resource.to_s == 'internal_user'
      new_internal_user_session_path
    else
      super
    end
  end

  def build_condition(field, column = nil, condition_type = '=', value = nil)
    @conditions ||= []
    column ||= field.to_s
    value ||= params[field]
    if params && value.present?
      @conditions[0] = initial_condition(column, condition_type)
      @conditions << condition_value(condition_type, value)
    end
    value
  end

  def mail_inbox(business)
    @page_mails = []
    return if business.submission_email.blank? || business.submission_password.blank?

    begin
      imap = Net::IMAP.new('mail.peachylake.com', 993, true)
      imap.login(business.submission_email, business.submission_password)
      imap.select('INBOX')
      @mail_ids = imap.search(['ALL'])
      # unread_ids = imap.search(['UNSEEN'])
      @page_mails = @mail_ids.reverse()
      @page_mails.each do |mail|
        mail_body = imap.fetch(mail, '(ENVELOPE RFC822 BODY[TEXT])')[0]
        envelope = mail_body.attr['ENVELOPE']
        message = Mail.read_from_string(mail_body.attr['RFC822'])
        # read = if unread_ids.include?(mail)
        #         false
        #       else
        #         true
        #       end
        if message.multipart? && message.html_part.present?
          body = message.html_part.decoded.force_encoding("UTF-8").encode("UTF-8")
          body = body.split('<a').join('<a target="_blank"')
        else
          if message.charset
            body = message.body.decoded.force_encoding(message.charset).encode("UTF-8")
            body = body.split('<a').join('<a target="_blank"')
          else
            body = message.body.decoded.force_encoding("UTF-8").encode("UTF-8")
            regexp = /https?:\/\/[^:\s"'<>#\(\)\[\]\{\},;]+/mi
            body = body.gsub(regexp, '<a href="\0" target="_blank">\0</a>')
          end
        end
        @mails.push({ envelope: envelope, body: body})
      end
      imap.logout()
    rescue
      puts "============Invalid email================"
    end
    respond_to do |format|
      format.html
      format.js
    end
  end

  def mail_count(business)
    @mail_ids = {}
    return if business.submission_email.blank? || business.submission_password.blank?

    begin
      imap = Net::IMAP.new('mail.peachylake.com', 993, true)
      imap.login(business.submission_email, business.submission_password)
      imap.select('INBOX')
      @mail_ids = imap.search(['ALL'])
      imap.logout()
    rescue
      puts "============Invalid email================"
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(
      :sign_up, keys: %i[first_name last_name email password
                         password_confirmation company_name country]
    )
    devise_parameter_sanitizer.permit(
      :account_update, keys: %i[first_name last_name email password
                                password_confirmation company_name country current_password]
    )
  end

  def layout_by_resource
    if devise_controller?
      if controller_name == 'registration' && action_name == 'edit'
        'business'
      else
        'devise'
      end
    else
      'business'
    end
  end

  def initial_condition(column, condition_type)
    @conditions[0].to_s +
      (@conditions[0].blank? ? '' : ' and ') +
      "#{column} #{condition_type} (?) "
  end

  def condition_value(type, value)
    case type
    when 'like'
      "%#{value}%"
    when '=', '!=', '>=', '<=', '>', '<', 'IN'
      value
    end
  end

  def audit_current_user
    class_name = self.class.name.split('::').first
    if ['InternalUsers', 'DataExtract', 'Moderator', 'PhaseB'].include? class_name
      current_internal_user
    elsif class_name == 'Account'
      current_user
    elsif class_name == 'Partners'
      current_partners_partner_user
    elsif class_name == 'Admins'
      current_admin
    end
  end
end
