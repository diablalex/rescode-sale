# frozen_string_literal: true

module Account
  #:nodoc:
  class BusinessController < BaseController
    include ApplicationHelper
    before_action :authenticate_user!
    skip_before_action :verify_authenticity_token, raise: false
    before_action :set_business, only: %i[edit show update destroy business_sites]
    before_action :set_peginate, only: %i[index invoice_details]
    before_action :check_subscription, only: %i[edit show]
    before_action :set_established_year, only: %i[create update]

    def new
      business_title
      @business = Business.new
      @business.business_hours.build
      FileUtils.rm_rf("public/images/user/#{current_user.id}/")
    end

    def index
      business_title
      @businesses = current_user.businesses.is_active
                                .order(id: :asc)
                                .page(@page).per(@per_page)
      if params[:search].present?
        @businesses = @businesses.search(params[:search])
                                 .order(id: :asc)
                                 .page(@page).per(@per_page)
      end
    end


    private

    def set_business
      @business = current_user.businesses.find_by(id: params[:id])
    end

    def business_params
      params[:business].permit(
        Business.column_names.map(&:to_sym).push(:logo),
        business_hours_attributes: [{ day: [] }, :start_time, :end_time, :business_id, :_destroy, :id]
      )
    end

    def set_established_year
      if params[:business].present?
        year = params[:business][:established_year]
        if year.present?
          params[:business][:established_year] = DateTime.strptime(year, '%Y')
        end
      end
    end

    def check_subscription
      if @business.present?
        unless @business.is_subscribe?
          redirect_to account_business_index_path,
                      alert: 'Subscription is reamin for this business.'
        end
      end
    end

    def business_title
      @title = 'ReputeSales :: User Business'
    end

    def invoice_title
      @title = 'ReputeSales :: User Invoice'
    end
  end
end
