require 'active_support/lazy_load_hooks'
require 'socket'
require 'singleton'

# FIXME: 1サーバーで1Railsインスタンスしか建てられない

module MessageReceiver
  class SocketObject
    include Singleton
    attr_reader :socket

    def self.recvfrom_nonblock(&block)
      resp = instance.recvfrom_nonblock
      block.call(resp) if resp
    end

    def self.open
      instance.open
    end

    def self.close
      instance.close
    end

    # @return [Array] `["data", ["AF_INET", 65483, "192.168.108.21", "192.168.108.21"]]`
    def recvfrom_nonblock
      @socket.recvfrom_nonblock(65535) if open
    rescue IO::EAGAINWaitReadable
      nil
    end

    def open
      @socket = UDPSocket.open.tap { |sock| sock.bind('0.0.0.0', 3610) } if @socket.nil? || @socket.closed?
      !@socket.closed?
    end

    def close
      @socket.close if @socket
    end
  end

  # Rails ServerでUDPを受け付ける
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      # open UDPSocket
      MessageReceiver::SocketObject.open

      @app.call(env)
    end
  end

  class Railtie < ::Rails::Railtie
    initializer 'message_receiver' do |app|
      app.middleware.use MessageReceiver::Middleware unless Rails.env.test?

      app.reloader.before_class_unload do
        MessageReceiver::SocketObject.close
      end
    end
  end
end
