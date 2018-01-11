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

    def edit
      business_title
      @images = @business.gallery
      @blobs = ActiveStorage::Blob.where(id: @images.pluck(:blob_id)) if @images.present?
      if @blobs.present?
        @existingFiles = []
        @blobs.each do |image|
          data = {}
          data[:filename] = image['filename']
          data[:size] = image.byte_size
          data[:url] = url_for(image)
          data[:key] = image.key
          @existingFiles << data
        end
      end
    end

    def show
      business_title
    end

    def create
      @business = current_user.businesses.new(business_params)
      files_name = session[:fil_name] if session[:fil_name].present?
      if files_name.present?
        files_name.each do |name|
          url = Rails.root.join('public', 'images', 'user', current_user.id.to_s, name)
          begin
            @business.gallery.attach(io: File.open(url), filename: name)
          rescue URI::InvalidURIError
            puts '======URI::InvalidURIError========'
          end
        end
      end
      respond_to do |format|
        if @business.save
          session[:fil_name] = []
          FileUtils.rm_rf("public/images/user/#{current_user.id}/")
          if session['plan_' + current_user.id.to_s].present?
            plan = Plan.find_by(id: session['plan_' + current_user.id.to_s])
            session.delete('plan_' + current_user.id.to_s)
          end
          if plan.present?
            format.html do
              redirect_to checkout_account_subscriptions_path(business: @business.id,
                                                              plan: plan.stripe_plan_id)
            end
          else
            format.html do
              redirect_to new_account_subscription_path(business: @business.id),
                          notice: 'Business was successfully created'
            end
            format.json { render :show, status: :created, location: @business }
          end
        else
          format.html { render :new, alert: @business.errors.full_messages.join(', ') }
          format.json { render json: @business.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      respond_to do |format|
        if @business.update(business_params)
          if @business.tag_misc == nil
            @business.tag_misc = {}
          end
          @business.tag_misc['Update'] = '1'
          @business.save
          format.html do
            redirect_to account_business_index_path,
                        notice: 'Business was successfully updated.'
          end
          format.json { render json: { type: request.params[:business].keys.join(',') } }
        else
          @images = @business.gallery
          @blobs = ActiveStorage::Blob.where(id: @images.pluck(:blob_id)) if @images.present?
          if @blobs.present?
            @existingFiles = []
            @blobs.each do |image|
              data = {}
              data[:filename] = image['filename']
              data[:size] = image.byte_size
              data[:url] = url_for(image)
              data[:key] = image.key
              @existingFiles << data
            end
          end
          format.html { render :edit, alert: @business.errors.full_messages.join(', ') }
          format.json { render json: @business.errors, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @business.destroy
      respond_to do |format|
        format.html do
          redirect_to account_business_index_path,
                      notice: 'Business was successfully destroyed.'
        end
        format.json { head :no_content }
      end
    end

    def get_state
      @states = CS.states(params[:country])
      @selected_state = params[:state] if params[:state].present?
    end

    def categories
      if params[:search].present?
        @categories = Category.where('lower(name) LIKE ?', "%#{params[:search].downcase}%")
        render json: @categories.map { |c| c.serializable_hash(only: %i[name name]) }
      else
        render json: Category.all.map { |c| c.serializable_hash(only: %i[name name]) }
      end
    end

    def uploadfiles
      if params[:id].present?
        @business = current_user.businesses.find_by(id: params[:id])
        if @business.present?
          uploaded_pics = params[:file]
          if uploaded_pics.present?
            uploaded_pics.each do |pic|
              @business.gallery.attach(io: pic.last, filename: pic.last.original_filename, content_type: 'image/jpg')
            end
          end
          render json: { message: 'You have successfully uploded your images.' }
        end
      else
        FileUtils.mkdir_p("public/images/user/#{current_user.id}/") unless File.exist?("public/images/user/#{current_user.id}")
        session[:fil_name] = []
        uploaded_pics = params[:file]
        time_footprint = Time.now.to_i
        if uploaded_pics.present?
          uploaded_pics.each do |pic|
            next if pic[1].blank?

            File.open(Rails.root.join('public', 'images', 'user', current_user.id.to_s ,pic[1].original_filename), 'wb') do |file|
              file.write(pic[1].read)
              File.rename(file, "public/images/user/#{current_user.id}/" + pic[1].original_filename)
              session[:fil_name] << pic[1].original_filename
            end
          end
        end
        files_list = Dir["public/images/user/#{current_user.id}/*"].to_json
        render json: { message: 'You have successfully uploded your images.', files_list: files_list }
      end
    end

    def cancel_subscription
      subscription = BusinessPlan.find_by(id: params[:subscription_id])
      if subscription.present?
        begin
          if subscription.stripe_subscription_id.present?
            stripe_subscription = Stripe::Subscription.delete(subscription.stripe_subscription_id)
            subscription.status      = stripe_subscription[:status]
          else
            subscription.status      = 'canceled'
          end
          if subscription.save
            business = subscription.business
            business.update(is_subscribe: false)
            # if business.tag_misc == nil
            #   business.tag_misc = {}
            # end
            # business.tag_misc['Update'] = '1'
            # business.save
            redirect_to account_business_index_path,
                        notice: 'subscription will be canceled_at next payment date.'
          else
            redirect_to account_business_index_path,
                        alert: 'Please try Again Later.'
          end
        rescue Stripe::StripeError => e
          puts '=======ERROR=======StripeError========'
          redirect_to account_business_index_path, alert: e.error[:message]
        end
      else
        redirect_to account_business_index_path, alert: 'Subscription Not Found !!!!'
      end
    end

    def business_sites
      business_title
      @business_sites = @business.business_sites
    end

    def save_code
      business_site = BusinessSite.find_by(id: params[:business_site][:id])
      if business_site.present?
        business_site.code = params[:business_site][:code]
        business_site.status = 'Confirmation code submitted'
        if business_site.save
          redirect_to business_sites_account_business_path(id: params[:business_id]),
                      notice: 'code updated successfully.'
          business = business_site.business
          if business.tag_misc == nil
            business.tag_misc = {}
          end
          business.tag_misc.delete('Verification code - Fail') if business.tag_misc['Verification code - Fail'].present?
          business.tag_misc['Verification code - Submitted'] = '1'
          business.save
        else
          redirect_to business_sites_account_business_index_path,
                      alert: 'Please try again later.'
        end
      else
        redirect_to business_sites_account_business_index_path,
                    alert: 'Site not found.'
      end
    end

    def invoice_details
    end

    def confirm_invoice
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
