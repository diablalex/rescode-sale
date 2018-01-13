# frozen_string_literal: true

module Admins
  #:nodoc:
  class BaseController < ApplicationController
    layout 'admin'
    include ApplicationHelper
    skip_before_action :verify_authenticity_token, raise: false
    before_action :authenticate_admin!
    before_action :set_title

    def set_index
      @page_index = (@page - 1) * @per_page
    end

    def set_title
      @title = 'ReputeSales :: Admin'
    end

    def generate_invoice_no
      prefix = 'ASLP'
      user_no = UserInvoice.where('invoice_no like ?', "#{prefix}%").last.try(:invoice_no)
                           .to_s.gsub(prefix, '').to_i + 1
      partner_no = PartnerInvoice.where('invoice_no like ?', "#{prefix}%").last.try(:invoice_no)
                                 .to_s.gsub(prefix, '').to_i + 1
      no = user_no > partner_no ? user_no : partner_no
      @invoice_no = prefix + no.to_s.rjust(3, '0')
    end
  end
end
