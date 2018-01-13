# frozen_string_literal: true

module Admins
  #:nodoc:
  class CompanyController < BaseController
    before_action :set_company, only: %i[index update]
    def index; end

    def update
      if @company.update(company_params)
        flash[:notice] = 'Company Updated Successfully'
      else
        flash[:alert] = @company.errors.full_messages.join(',')
      end
      redirect_to admins_company_index_path
    end

    private

    def set_company
      @company = CompanySetting.first
    end

    def company_params
      params.require(:company_setting).permit(
        :copyright, :name, :address
      )
    end
  end
end
