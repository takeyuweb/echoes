require 'timeout'
class ReceiveMessageJob < ApplicationJob
  queue_as :message_receiver

  def perform(wait=10)
    Timeout.timeout(wait) do
      loop do
        MessageReceiver::SocketObject.recvfrom_nonblock do |data, address_info|
          Rails.logger.info "Received: #{data.chomp.unpack('H*')} from #{address_info[3]}"
        end
        sleep 0.1
      end
    end
  rescue Timeout::Error
    # (noop)
  end
end
