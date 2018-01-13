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

    def pending_business(date1, date2)
      @labels = []
      @no_of_pending_businesses = []
      start_date = Date.parse(date1)
      end_date = Date.parse(date2)
      (start_date..end_date).each do |date|
        @labels << date.strftime('%a, %d %b %Y')
        businesses = Business.left_joins(:business_plans, :partner_user_business_plans)
                             .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
                                    From partner_user_business_plans where
                                    partner_user_business_plans.business_id = businesses.id) OR
                                    business_plans.id = (select max(business_plans.id)
                                    From business_plans where
                                    business_plans.business_id = businesses.id)")
                             .where('DATE(businesses.created_at) = ?', date.to_date)
                             .where('business_plans.expire_date >= ? or
                                     partner_user_business_plans.expire_date > ?',
                                     Time.zone.now, Time.zone.now)
                             .where(status: %w[new inprogress seo-new seo-inprogress])
        if businesses.present?
          # count = []
          # businesses.each do |business|
          #   count << business.pending_business
          # end
          # count = if count.present?
          #           count.sum
          #         else
          #           0
          #         end
          @no_of_pending_businesses << businesses.count
        else
          @no_of_pending_businesses << 0
        end
      end
      @arr = []
      @arr << @labels.reverse.unshift('x')
      @arr << @no_of_pending_businesses.reverse.unshift('Business')
      @arr
    end

    def todays_number_of_business
      @date = Date.today
      @count = Business.where('DATE(created_at) = ?', @date.to_date)
                       .group_by_hour_of_day(:created_at).count.to_a
    end

    def current_month_number_of_business
      date_counts = {}
      current_month_tick_list = []
      (Time.zone.now.beginning_of_month.to_date..Time.zone.now.end_of_month.to_date).each_with_index do |date, index|
        date_counts[date]=0
        current_month_tick_list << [(index + 1), date.strftime('%d')]
      end
      @current_month_tick_list = current_month_tick_list
      date_counts.merge! Business.this_month.group("date(created_at)").count
      @current_month_label_list = date_counts.each_with_index.map { |x, i| x.drop(1).unshift(x.first.strftime('%d %b'))}.to_h.keys
      @current_month_business = date_counts.to_a.each_with_index.map { |x, i| x.drop(1).unshift(x.first.strftime('%d')).map(&:to_i) }
    end

    def months_between(start_month, end_month)
      months = []
      ptr = start_month
      while ptr <= end_month do
        months << ptr
        ptr = ptr >> 1
      end
      months
    end

    def current_year_number_of_business
      months = months_between(Time.zone.now.beginning_of_year.to_date, Time.zone.now.end_of_year.to_date)
      current_year_tick_list = []
      month_wise_business_data = []
      months.each_with_index do |month, index|
        if month.present?
          count  = Business.where(created_at: month..((month + 1.month).midnight)).count
          count = 0 if !count.present?
          month_wise_business_data << [(index + 1), count]
        else
          month_wise_business_data << [(index + 1), 0]
        end
      end
      @current_year_business = month_wise_business_data
    end

    def five_year_number_of_business
      five_year_tick_list = []
      five_year_business_data = []
      ((Time.zone.now.beginning_of_year - 5.years).strftime("%Y").to_i..Time.zone.now.end_of_year.strftime("%Y").to_i).each_with_index do |year, index|
        five_year_tick_list << [(index + 1), year.to_s]
        if year.present?
          full_year = DateTime.strptime(year.to_s, "%Y")
          count  = Business.where(created_at: full_year..((full_year + 1.year).midnight)).count
          count = 0 if !count.present?
          five_year_business_data << [(index + 1), count]
        else
          five_year_business_data << [(index + 1), 0]
        end
      end
      @five_year_business_data = five_year_business_data
      @five_year_tick_list = five_year_tick_list
    end

    def get_partner_profit
      ids = Business.paid.where(businessable_type: 'PartnerUser').ids
      pu_plans = PartnerUserBusinessPlan.where(business_id: ids)
                                        .joins(:partner_user_plan)
                                        .pluck(:partner_user_plan_id)
      total = []
      pu_plans.each do |pl|
        plan = PartnerUserPlan.find_by(id: pl)
        plan_price = plan.price
        partner_price = plan.partner_price
        pay_to_client = (plan_price * partner_price / 100)
        total << partner_price.presence || 0
      end
      get_total_amount(total)
    end

    def get_end_user_profit
      ids = Business.paid.where(businessable_type: 'User').ids
      plans = BusinessPlan.where(business_id: ids, is_free: false)
                          .joins(:plan)
                          .pluck(:plan_id)
      total = []
      plans.each do |plan|
        a = Plan.find_by(id: plan).price
        total << a.presence || 0
      end
      get_total_amount(total)
    end

    def get_total_amount(total)
      if total.present?
        total.sum
      else
        0
      end
    end

    def partner_business_ids
      @partner_businesses.ids
    end

    def end_user_business_ids
      @end_user_businesses.ids
    end

    def end_user_canceled_subscriptions
      @end_user_businesses.joins(business_plans: :plan)
                          .where("business_plans.id = (select max(business_plans.id) From business_plans where business_plans.business_id = businesses.id)")
                          .where(business_plans: {status: 'canceled'}).distinct.count
    end

    def partner_canceled_subscriptions
      @partner_businesses.joins(partner_user_business_plans: :partner_user_plan)
                          .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id) From partner_user_business_plans where partner_user_business_plans.business_id = businesses.id)")
                          .where(partner_user_business_plans: {status: 'canceled'}).distinct.count
    end

    def partners_total_subscription_unpaid
      Business.where(id: partner_business_ids).unpaid.count
    end

    def partners_total_income
      [total_inr_income, total_usd_income]
    end

    def total_partner_yearly_income
      [total_yearly_inr_price, total_yearly_usd_price]
    end

    def total_partner_monthly_income
      [total_monthly_inr_price, total_monthly_usd_price]
    end

    def end_users_total_income
      businesses = Business.where(id: end_user_business_ids)
      if businesses.present?
        get_end_users_total_amount(businesses.paid.ids)
      else
        0
      end
    end

    def total_end_user_yearly_income
      businesses = Business.where(id: end_user_business_ids).this_year
      if businesses.present?
        get_end_users_total_amount(businesses.paid.ids)
      else
        0
      end
    end

    def total_end_user_monthly_income
      businesses = Business.where(id: end_user_business_ids).this_month
      if businesses.present?
        get_end_users_total_amount(businesses.paid.ids)
      else
        0
      end
    end

    def total_end_user_daily_income
      businesses = Business.where(id: end_user_business_ids).today
      if businesses.present?
        get_end_users_total_amount(businesses.paid.ids)
      else
        0
      end
    end

    def get_partners_total_amount(ids)
      total_inr = PartnerUserBusinessPlan.joins(:partner_user_plan)
                                         .where(business_id: ids,
                                                partner_user_plans: { inr_price: true })
                                         .sum('partner_user_plans.price')
      total_usd = PartnerUserBusinessPlan.joins(:partner_user_plan)
                                         .where(business_id: ids,
                                               partner_user_plans: { inr_price: false })
                                         .sum('partner_user_plans.price')
      [total_inr, total_usd]
    end

    def get_end_users_total_amount(ids)
      plans = BusinessPlan.where(business_id: ids)
                          .joins(:plan, :business)
                          .where("business_plans.id = (select max(business_plans.id)
                                From business_plans where
                                business_plans.business_id = businesses.id)")
                          .pluck(:plan_id)
      total = []
      begin
        doller_inr_price = Concurrency.convert(1)
      rescue StandardError
        doller_inr_price = 73
      end
      plans.each do |pl|
        a = Plan.find_by(id: pl)
        total << ( a.inr_price ? a.price : a.price * doller_inr_price )
      end
      total.sum
    end

    def admin_review
      admins_id = InternalUser.where(role: 'admin').pluck(:id)
      Business.joins(:assign_business).where(assign_businesses: { handled: false, internal_user_id: admins_id }).count
    end

    def total_monthly_inr_price
      inr_price = 0
      Partner.all.each do |partner|
        @inr_plans = partner.partner_user_business_plans.joins(:partner_user_plan,
                                                                       :business)
                                    .includes(:partner_user_plan, :business)
                                    .where(businesses: {is_subscribe: true},
                                           partner_user_plans: {inr_price: true})
                                    .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
                                          From partner_user_business_plans where
                                          partner_user_business_plans.business_id = businesses.id)")
                                    .where("to_char(partner_user_business_plans.expire_date, 'MMYY') >= ?",
                                           Time.zone.now.strftime('%m%y'))
        @inr_plans.where('extract(month from partner_user_business_plans.created_at) <= ?
                       and partner_user_plans.yearly = ?', Time.zone.now.month, false)
                  .each do |business_plan|
          inr_price += count_month_price(business_plan)
        end
        @inr_plans.where('extract(month from partner_user_business_plans.created_at) = ?
                       and extract(year from partner_user_business_plans.created_at) <= ? and
                       partner_user_plans.yearly = ?', Time.zone.now.month, Time.zone.now.year, true)
                  .each do |business_plan|
          inr_price += count_month_price(business_plan)
        end
      end
      inr_price
    end

    def total_monthly_usd_price
      usd_price = 0
      Partner.all.each do |partner|
        @usd_plans = partner.partner_user_business_plans.joins(:partner_user_plan,
                                                                       :business)
                                    .includes(:partner_user_plan, :business)
                                    .where(businesses: {is_subscribe: true},
                                           partner_user_plans: {inr_price: false})
                                    .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
                                          From partner_user_business_plans where
                                          partner_user_business_plans.business_id = businesses.id)")
                                    .where("to_char(partner_user_business_plans.expire_date, 'MMYY') >= ?",
                                           Time.zone.now.strftime('%m%y'))
        @usd_plans.where('extract(month from partner_user_business_plans.created_at) <= ?
                          and partner_user_plans.yearly = ?', Time.zone.now.month, false)
                  .each do |business_plan|
          usd_price += count_month_price(business_plan)
        end
        @usd_plans.where('extract(month from partner_user_business_plans.created_at) = ?
                       and extract(year from partner_user_business_plans.created_at) <= ? and
                       partner_user_plans.yearly = ?', Time.zone.now.month, Time.zone.now.year, true)
                  .each do |business_plan|
        end
      end
      usd_price
    end

    def total_yearly_inr_price
      inr_price = 0
      Partner.all.each do |partner|
        @inr_plans = partner.partner_user_business_plans.joins(:partner_user_plan, :business)
                       .where(businesses: {is_subscribe: true}, partner_user_plans: {inr_price: true} )
                       .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
                               From partner_user_business_plans where
                               partner_user_business_plans.business_id = businesses.id)")
        @inr_plans.where("partner_user_business_plans.created_at <= ?", Time.zone.now)
                  .each do |business_plan|
          inr_price += count_year_price(business_plan)
        end
      end
      inr_price
    end

    def total_yearly_usd_price
      usd_price = 0
      Partner.all.each do |partner|
        partner.partner_user_business_plans.joins(:partner_user_plan, :business)
                       .where(businesses: {is_subscribe: true}, partner_user_plans: {inr_price: false} )
                       .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
                               From partner_user_business_plans where
                               partner_user_business_plans.business_id = businesses.id)")
                       .where("partner_user_business_plans.created_at <= ?", Time.zone.now)
                               .each do |business_plan|
            usd_price += count_year_price(business_plan)
        end
      end
      usd_price
    end

    def total_inr_income
      inr_price = 0
      Partner.all.each do |partner|
        @inr_plans = partner.partner_user_business_plans.joins(:partner_user_plan, :business)
                       .where(businesses: {is_subscribe: true}, partner_user_plans: {inr_price: true} )
                       .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
                               From partner_user_business_plans where
                               partner_user_business_plans.business_id = businesses.id)")
        @inr_plans.where("partner_user_business_plans.created_at <= ?", Time.zone.now)
                  .each do |business_plan|
          inr_price += count_total_price(business_plan)
        end
      end
      inr_price
    end

    def total_usd_income
      usd_price = 0
      Partner.all.each do |partner|
        @usd_plans = partner.partner_user_business_plans.joins(:partner_user_plan, :business)
                       .where(businesses: {is_subscribe: true}, partner_user_plans: {inr_price: false} )
                       .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
                               From partner_user_business_plans where
                               partner_user_business_plans.business_id = businesses.id)")
        @usd_plans.where("partner_user_business_plans.created_at <= ?", Time.zone.now)
                  .each do |business_plan|
          usd_price += count_total_price(business_plan)
        end
      end
      usd_price
    end


    def inr_due_amount
      inr_price = 0
      Partner.all.each do |partner|
        @invoice_inr_price = check_inr_invoice(partner)
        partner.partner_user_business_plans.joins(:partner_user_plan, :business)
               .where(businesses: {is_subscribe: true}, partner_user_plans: {inr_price: true} )
               .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
                       From partner_user_business_plans where
                       partner_user_business_plans.business_id = businesses.id)")
               .where("partner_user_business_plans.created_at <= ?", Time.zone.now)
               .each do |business_plan|
            inr_price += count_inr_partner_price(business_plan)
        end
        # inr_price
        # if @invoice_inr_price.blank?
        #   @inr_plans = partner.partner_user_business_plans
        #                       .joins(:partner_user_plan, :business)
        #                       .includes(:partner_user_plan, :business)
        #                       .where.not(status: 'canceled')
        #                       .where(businesses: {is_subscribe: true},
        #                              partner_user_plans: {inr_price: true})
        #                       .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
        #                               From partner_user_business_plans where
        #                               partner_user_business_plans.business_id = businesses.id)")
        #   @inr_plans.where('extract(month from partner_user_business_plans.created_at) <= ?
        #                    and partner_user_plans.yearly = ?', Time.zone.now.month, false)
        #             .each do |business_plan|
        #     inr_price += count_due_partner_price(business_plan)
        #   end
        #   @inr_plans.where('extract(month from partner_user_business_plans.created_at) = ?
        #                    and extract(year from partner_user_business_plans.created_at) <= ? and
        #                    partner_user_plans.yearly = ?', Time.zone.now.month, Time.zone.now.year, true)
        #             .each do |business_plan|
        #     inr_price += count_due_partner_price(business_plan)
        #   end
        # else
        #   inr_price += 0
        # end
      end
      inr_price
    end

    def usd_due_amount
      usd_price = 0
      Partner.all.each do |partner|
        @invoice_usd_price = check_usd_invoice(partner)
        partner.partner_user_business_plans.joins(:partner_user_plan, :business)
               .where(businesses: {is_subscribe: true}, partner_user_plans: {inr_price: false} )
               .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
                       From partner_user_business_plans where
                       partner_user_business_plans.business_id = businesses.id)")
               .where("partner_user_business_plans.created_at <= ?", Time.zone.now)
               .each do |business_plan|
            usd_price += count_usd_partner_price(business_plan)
        end
        # if @invoice_usd_price.blank?
        #   @usd_plans = partner.partner_user_business_plans
        #                       .joins(:partner_user_plan, :business)
        #                       .includes(:partner_user_plan, :business)
        #                       .where.not(status: 'canceled')
        #                       .where(businesses: {is_subscribe: true},
        #                              partner_user_plans: {inr_price: false})
        #                       .where("partner_user_business_plans.id = (select max(partner_user_business_plans.id)
        #                             From partner_user_business_plans where
        #                             partner_user_business_plans.business_id = businesses.id)")
        #   @usd_plans.where('extract(month from partner_user_business_plans.created_at) <= ?
        #                     and partner_user_plans.yearly = ?', Time.zone.now.month, false)
        #             .each do |business_plan|
        #     usd_price += count_due_partner_price(business_plan)
        #   end
        #   @usd_plans.where('extract(month from partner_user_business_plans.created_at) = ?
        #                  and extract(year from partner_user_business_plans.created_at) <= ? and
        #                  partner_user_plans.yearly = ?', Time.zone.now.month, Time.zone.now.year, true)
        #             .each do |business_plan|
        #     usd_price += count_due_partner_price(business_plan)
        #   end
        # else
        #   usd_price += 0
        # end
      end
      usd_price
    end

    def check_inr_invoice(partner)
      partner.partner_invoices.where(inr: true, paid: true).last
    end

    def check_usd_invoice(partner)
      partner.partner_invoices.where(inr: false, paid: true).last
    end

    def count_month_price(business_plan)
      # count = if business_plan.partner_user_plan.yearly
      #           (Time.zone.now.year - business_plan.created_at.year) + 1
      #         else
      #           (Time.zone.now.month - business_plan.created_at.month) + 1
      #         end
      business_plan.partner_user_plan.price || 0
    end

    def count_year_price(business_plan)
      count = 0
      if business_plan.expire_date.to_date < Time.zone.today
        if business_plan.expire_date.year == Time.zone.now.year
          if business_plan.partner_user_plan.yearly
            count = 1
          else
            count = business_plan.expire_date.month
          end
        end
      else
        if business_plan.partner_user_plan.yearly
          count = (Time.zone.now.year - business_plan.created_at.year) + 1
        else
          if business_plan.created_at.year < Time.zone.now.year
            count = Time.zone.now.month
          else
            count = (Time.zone.now.month - business_plan.created_at.month) + 1
          end
        end
      end
      business_plan.partner_user_plan.price * count
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
