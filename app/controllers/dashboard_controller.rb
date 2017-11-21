class DashboardController < ApplicationController
  def index
    prepare_interfaces
    @devices = Device.all
  end

  def search
    SearchJob.perform_later(params[:interface].presence || '0.0.0.0')

    prepare_interfaces
    @devices = Device.all
    render action: :index
  end

  private

  def prepare_interfaces
    @interfaces =
      Socket.getifaddrs.select{|ifaddr| ifaddr.addr.ipv4? || ifaddr.addr.ipv6?}.map { |ifaddr| ifaddr.addr.ip_address }
  end
end
