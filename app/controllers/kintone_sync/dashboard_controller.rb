require_dependency "kintone_sync/application_controller"

module KintoneSync
  class DashboardController < ApplicationController
    def index
      @kntn = KintoneSync::Kintone.new
    end
  end
end
