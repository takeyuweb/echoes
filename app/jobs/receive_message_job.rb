require 'timeout'
class ReceiveMessageJob < ApplicationJob
  queue_as :message_receiver

  def perform(wait=10)
    Timeout.timeout(wait) do
      loop do
        MessageReceiver::SocketObject.recvfrom_nonblock do |data, address_info|
          HandleMessageService.call(data, address_info)
        end
        sleep 0.1
      end
    end
  rescue Timeout::Error
    # (noop)
  end
end
