require 'socket'

class SearchJob < ApplicationJob
  queue_as :default

  def perform(addr='192.168.108.101')
    ReceiveMessageJob.perform_later(3, 10)

    # すべてノードに対して，ノードプロファイルを要求する
    msg = [
      0x10, # EHD1 固定
      0x81, # EHD2 固定
      0x00, 0x00, # TID
      0x05, 0xFF, 0x01, # SEOJ 送信元ECHONET Liteオブジェクト指定 最初の2バイトが種類、残り1バイトがインスタンスID。この場合は種類がコントローラー、インスタンスIDが1
      0x0E, 0xF0, 0x01, # DEOJ 送信先ECHNET Liteオブジェクト指定 0EF001 『ノードプロファイル』を指定
      0x62, # ESV Setl=0x60 SetC=0x61 Get=0x62
      0x01, # OPC 処理プロパティ数
      0xD6, # EPC1 自ノードインスタンスリスト=0xD6
      0x00, # EDT1
    ].pack('C*')

    UDPSocket.open do |udp|
      socketaddr = Socket.pack_sockaddr_in(3610, '224.0.23.0') # Echonet専用のマルチキャストアドレス
      mif = IPAddr.new(addr).hton
      udp.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, mif)
      udp.send(msg, 0, socketaddr)
      udp.close
    end
  end
end
