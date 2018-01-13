# frozen_string_literal: true

module Admins
  #:nodoc:
  class AdminsController < BaseController
    before_action :set_peginate, only: :index
    before_action :set_admin, only: %i[show edit update destroy]

    def index
      @admins = Admin.all
    end

    def new
      @admin = Admin.new
    end

    def create
      @admin = Admin.new(admin_params)
      if @admin.save
        flash[:notice] = 'Admin successfully created.'
        redirect_to admins_admins_path
      else
        flash[:error] = 'Failed to create admin!'
        render :new
      end
    end

    def edit; end


    private

    def set_admin
      @admin = Admin.find_by(id: params[:id])
    end

    def admin_params
      params.require(:admin).permit(
        Admin.column_names.map(&:to_sym).push(:password)
      )
    end
  end
end
