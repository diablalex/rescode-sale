# frozen_string_literal: true

module Admins
  #:nodoc:
  class DashboardController < BaseController
    def index
      @end_user_businesses = Business.where(businessable_type: 'User')
      @total_end_user_businesses = @end_user_businesses.count
      @total_end_user_active_businesses = @end_user_businesses.joins(business_plans: :plan).where(is_subscribe: true)
                                                              .where("business_plans.id = (select max(business_plans.id) From business_plans where business_plans.business_id = businesses.id)")
                                                              .where.not(business_plans: {status: 'canceled'}).distinct.count
      @total_monthly_end_user_businesses = @end_user_businesses.joins(business_plans: :plan).where(plans: {yearly: false})
                                                               .where("business_plans.id = (select max(business_plans.id) From business_plans where business_plans.business_id = businesses.id)")
                                                               .where.not(business_plans: {status: 'canceled'}).distinct.count
      @total_yearly_end_user_businesses = @end_user_businesses.joins(business_plans: :plan).where(plans: {yearly: true})
                                                              .where("business_plans.id = (select max(business_plans.id) From business_plans where business_plans.business_id = businesses.id)")
                                                              .where.not(business_plans: {status: 'canceled'}).distinct.count
      @total_end_user_end_users  = User.owner.count
      @total_internal_users  = InternalUser.count
      @total_pending_subscription = @end_user_businesses.unpaid.count

      @total_end_user_canceled_subscriptions = end_user_canceled_subscriptions
      @total_end_user_income = end_users_total_income
      @total_end_user_yearly_income = total_end_user_yearly_income
      @total_end_user_monthly_income = total_end_user_monthly_income
      @total_end_user_daily_income = total_end_user_daily_income

      @partner_businesses = Business.where(businessable_type: 'PartnerUser')
      @total_partners_businesses = @partner_businesses.count
      @total_partners_active_businesses = @partner_businesses.joins(partner_user_business_plans: :partner_user_plan).where(is_subscribe: true)
                                                            .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id) From partner_user_business_plans where partner_user_business_plans.business_id = businesses.id)")
                                                            .where.not(partner_user_business_plans: {status: 'canceled'}).distinct.count
      @total_monthly_partner_businesses = @partner_businesses.joins(partner_user_business_plans: :partner_user_plan).where(partner_user_plans: {yearly: false})
                                                             .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id) From partner_user_business_plans where partner_user_business_plans.business_id = businesses.id)")
                                                             .where.not(partner_user_business_plans: {status: 'canceled'}).distinct.count
      @total_yearly_partner_businesses = @partner_businesses.joins(partner_user_business_plans: :partner_user_plan).where(partner_user_plans: {yearly: true})
                                                            .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id) From partner_user_business_plans where partner_user_business_plans.business_id = businesses.id)")
                                                            .where.not(partner_user_business_plans: {status: 'canceled'}).distinct.count
      @total_partners = Partner.count
      @total_partners_users = PartnerUser.count
      @total_partners_canceled_subscriptions = partner_canceled_subscriptions
      @total_partners_total_subscription_unpaid = partners_total_subscription_unpaid

      @total_inr_partner_income, @total_usd_partner_income = partners_total_income
      @total_inr_partner_yearly_income, @total_usd_partner_yearly_income = total_partner_yearly_income
      @total_inr_partner_monthly_income, @total_usd_partner_monthly_income = total_partner_monthly_income

      @total_pending_activation_partners = Partner.where(approved: false).count
      @total_inr_due_payment, @total_usd_due_payment = total_due_payment
      @admin_review = admin_review

      if params[:selected_dates].present?
        selected_dates = params[:selected_dates].split(' - ')
        @date1 = Date.strptime(selected_dates[0], '%m/%d/%Y').strftime('%d/%m/%Y')
        @date2 = Date.strptime(selected_dates[1], '%m/%d/%Y').strftime('%d/%m/%Y')
      else
        @date1 = (Date.today - 1.month).strftime('%d/%m/%Y')
        @date2 = Date.today.strftime('%d/%m/%Y')
      end
      logger.warn "========== date1 ========== #{@date1} =========="
      logger.warn "========== date2 ========== #{@date2} =========="
      if @date1.to_date > @date2.to_date
        redirect_to admins_dashboard_index_path, alert: 'Please select valid start date and end date.'
      else
        pending_business(@date1, @date2)
      end
      todays_number_of_business
      current_month_number_of_business
      current_year_number_of_business
      five_year_number_of_business
    end

    private

    def total_due_payment
      # businesses = Business.unpaid.where(businessable_type: 'PartnerUser')
      # if businesses.present?
      #   # abort businesses.joins(:partner_user_business_plans).pluck('id').inspect
      #   pubp_ids = businesses.joins(:partner_user_business_plans)
      #                        .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id) From partner_user_business_plans where partner_user_business_plans.business_id = businesses.id)")
      #                        .where.not(partner_user_business_plans: { status: 'canceled' })
      #                        .pluck(:id)
      #   inr_amount, usd_amount = get_partners_total_amount(pubp_ids)
      # else
      #   inr_amount, usd_amount = 0
      # end
      [inr_due_amount, usd_due_amount]
    end


    def count_total_price(business_plan)
      count = 0
      if business_plan.partner_user_plan.yearly
        if business_plan.expire_date.to_date < Time.zone.today
          count = (business_plan.expire_date.year - business_plan.created_at.year) + 1
        else
          count = (Time.zone.now.year - business_plan.created_at.year) + 1
        end
      else
        if business_plan.expire_date.to_date < Time.zone.today
          count = ((business_plan.expire_date.year * 12 + business_plan.expire_date.month) - (business_plan.created_at.year * 12 + business_plan.created_at.month)) + 1
        else
          count = ((Time.zone.now.year * 12 + Time.zone.now.month) - (business_plan.created_at.year * 12 + business_plan.created_at.month)) + 1
        end
      end
      business_plan.partner_user_plan.price * count
    end

    def count_inr_partner_price(business_plan)
      count = 0
      if (@invoice_inr_price.present? && Time.new(business_plan.created_at.year, business_plan.created_at.month) > Time.new(@invoice_inr_price.end_date.year, @invoice_inr_price.end_date.month)) || @invoice_inr_price.blank?
        if business_plan.expire_date.to_date < Time.zone.today
          if business_plan.partner_user_plan.yearly
            count = (business_plan.expire_date.year - business_plan.created_at.year) + 1
          else
            count = ((business_plan.expire_date.year * 12 + business_plan.expire_date.month) - (business_plan.created_at.year * 12 + business_plan.created_at.month)) + 1
          end
        else
          if business_plan.partner_user_plan.yearly
            count = (Time.zone.now.year - business_plan.created_at.year) + 1
          else
            count = ((Time.zone.now.year * 12 + Time.zone.now.month) - (business_plan.created_at.year * 12 + business_plan.created_at.month)) + 1
          end
        end
      else
        if business_plan.expire_date.to_date < Time.zone.today
          if business_plan.partner_user_plan.yearly
            count = business_plan.expire_date.year - @invoice_inr_price.end_date.year + 1
          else
            count = ((business_plan.expire_date.year * 12 + business_plan.expire_date.month) - (@invoice_inr_price.end_date.year * 12 + @invoice_inr_price.end_date.month))
          end
        else
          if business_plan.partner_user_plan.yearly
            count = Time.zone.now.year - @invoice_inr_price.end_date.year + 1
          else
            count = ((Time.zone.today.year * 12 + Time.zone.today.month) - (@invoice_inr_price.end_date.year * 12 + @invoice_inr_price.end_date.month))
          end
        end
      end
      business_plan.partner_user_plan.partner_price.to_f * count
    end

    def count_usd_partner_price(business_plan)
      count = 0
      if (@invoice_usd_price.present? && Time.new(business_plan.created_at.year, business_plan.created_at.month) > Time.new(@invoice_usd_price.end_date.year, @invoice_usd_price.end_date.month)) || @invoice_usd_price.blank?
        if business_plan.expire_date.to_date < Time.zone.today
          if business_plan.partner_user_plan.yearly
            count = (business_plan.expire_date.year - business_plan.created_at.year) + 1
          else
            count = ((business_plan.expire_date.year * 12 + business_plan.expire_date.month) - (business_plan.created_at.year * 12 + business_plan.created_at.month)) + 1
          end
        else
          if business_plan.partner_user_plan.yearly
            count = (Time.zone.now.year - business_plan.created_at.year) + 1
          else
            count = ((Time.zone.now.year * 12 + Time.zone.now.month) - (business_plan.created_at.year * 12 + business_plan.created_at.month)) + 1
          end
        end
      else
        if business_plan.expire_date.to_date < Time.zone.today
          if business_plan.partner_user_plan.yearly
            count = business_plan.expire_date.year - @invoice_usd_price.end_date.year + 1
          else
            count = ((business_plan.expire_date.year * 12 + business_plan.expire_date.month) - (@invoice_usd_price.end_date.year * 12 + @invoice_usd_price.end_date.month))
          end
        else
          if business_plan.partner_user_plan.yearly
            count = Time.zone.now.year - @invoice_usd_price.end_date.year + 1
          else
            count = ((Time.zone.today.year * 12 + Time.zone.today.month) - (@invoice_usd_price.end_date.year * 12 + @invoice_usd_price.end_date.month))
          end
        end
      end
      business_plan.partner_user_plan.partner_price.to_f * count
    end

    def count_due_partner_price(business_plan)
      business_plan.partner_user_plan.partner_price || 0
    end
  end
end
