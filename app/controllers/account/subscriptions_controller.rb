# frozen_string_literal: true

module Account
  #:nodoc:
  class SubscriptionsController < BaseController
    require 'stripe'
    include SubscriptionChange
    before_action :authenticate_user!, except: [:webhooks]
    before_action :check_business, except: [:webhooks]
    skip_before_action :verify_authenticity_token, only: [:webhooks]

    def new
      @title = 'ReputeSales :: User Subscription'
      @country = Geocoder.search(request.remote_ip).try(:first).try(:country)
      if @country == 'IN'
        @monthly_plans = Plan.where(yearly: false, inr_price: true, disabled: false).order(sequence_number: :asc)
        @yearly_plans = Plan.where(yearly: true, inr_price: true, disabled: false).order(sequence_number: :asc)
      else
        @monthly_plans = Plan.where(yearly: false, inr_price: false, disabled: false).order(sequence_number: :asc)
        @yearly_plans = Plan.where(yearly: true, inr_price: false, disabled: false).order(sequence_number: :asc)
      end
    end

  end
end
