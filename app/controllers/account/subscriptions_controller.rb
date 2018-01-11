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

    def checkout
      if @business.stripe_customer_id.blank?
        customer = Stripe::Customer.create({email: @business.email})
        @business.update(stripe_customer_id: customer.id)
      end
      session = Stripe::Checkout::Session.create(
        customer: @business.stripe_customer_id,
        payment_method_types: ['card'],
        subscription_data: {
          items: [{ plan: params[:plan] }]
        },
        success_url: account_business_index_url,
        cancel_url: root_url
      )
      @session_id = session.id
    end

    def webhooks
    end

    private

  end
end
