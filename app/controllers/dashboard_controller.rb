class DashboardController < ApplicationController
  def index
    @interfaces =
      Socket.getifaddrs.select{|ifaddr| ifaddr.addr.ipv4? || ifaddr.addr.ipv6?}.map { |ifaddr| ifaddr.addr.ip_address }
    @devices = Device.all
  end

  def search
    SearchJob.perform_later(params[:interface].presence || '0.0.0.0')
    redirect_to root_url, notice: 'スキャンを開始しました。'
  end
end
