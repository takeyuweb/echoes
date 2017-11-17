class DashboardController < ApplicationController
  def index
  end

  def search
    SearchJob.perform_later
    render action: :index
  end
end
