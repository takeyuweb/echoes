class HandleMessageService < ApplicationService
  def initialize(data, address_info)
    @data = data
    @address_info = address_info
  end

  def call
    Rails.logger.info "Received: #{@data.chomp.unpack('H*')} from #{@address_info[3]}"
  end
end