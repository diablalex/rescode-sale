# frozen_string_literal: true

module Account
  #:nodoc:
  class BaseController < ApplicationController
    layout 'business'
    include ApplicationHelper
  end
end
