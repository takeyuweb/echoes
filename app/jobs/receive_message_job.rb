require 'timeout'
class ReceiveMessageJob < ApplicationJob
  queue_as :message_receiver

  def perform(wait=10, repeat=1)
    Timeout.timeout(wait) do
      loop do
        MessageReceiver::SocketObject.recvfrom_nonblock do |data, address_info|
          HandleMessageService.call(data, address_info)
        end
      end
    end
    if repeat > 0
      ReceiveMessageJob.perform_later(wait, repeat - 1)
    end
  rescue Timeout::Error
    # (noop)
  end
end
