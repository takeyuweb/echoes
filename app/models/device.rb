class Device < ApplicationRecord
  belongs_to :node, required: true
  validates :name, presence: true
  validates :eoj, presence: true

  def ipaddr
    node.ipaddr
  end

  def set_i(*props)
    msg = [
      0x10, # EHD1 固定
      0x81, # EHD2 固定
      0x00, 0x00, # TID
      0x05, 0xFF, 0x01, # SEOJ 送信元ECHONET Liteオブジェクト指定 最初の2バイトが種類、残り1バイトがインスタンスID。この場合は種類がコントローラー、インスタンスIDが1
      hex_eoj, # DEOJ 送信先ECHNET Liteオブジェクト指定 0EF001 『ノードプロファイル』を指定
      0x60, # ESV Setl=0x60 SetC=0x61 Get=0x62
      props.size, # OPC 処理プロパティ数
      props
    ].flatten
    #raise msg.map{|v| format('0x%02X', v) }.inspect

    UDPSocket.open do |udp|
      udp.connect(node.ipaddr.to_s, 3610)
      udp.send(msg.pack('C*'), 0)
    end
  end

  def set_c(*props)
    ReceiveMessageJob.perform_later(3, 3)

    msg = [
      0x10, # EHD1 固定
      0x81, # EHD2 固定
      0x00, 0x00, # TID
      0x05, 0xFF, 0x01, # SEOJ 送信元ECHONET Liteオブジェクト指定 最初の2バイトが種類、残り1バイトがインスタンスID。この場合は種類がコントローラー、インスタンスIDが1
      hex_eoj, # DEOJ 送信先ECHNET Liteオブジェクト指定 0EF001 『ノードプロファイル』を指定
      0x61, # ESV Setl=0x60 SetC=0x61 Get=0x62
      props.size, # OPC 処理プロパティ数
      props
    ].flatten
    #raise msg.map{|v| format('0x%02X', v) }.inspect

    UDPSocket.open do |udp|
      udp.connect(node.ipaddr.to_s, 3610)
      udp.send(msg.pack('C*'), 0)
    end
  end

  def get(*props)
    ReceiveMessageJob.perform_later(3, 3)

    msg = [
      0x10, # EHD1 固定
      0x81, # EHD2 固定
      0x00, 0x00, # TID
      0x05, 0xFF, 0x01, # SEOJ 送信元ECHONET Liteオブジェクト指定 最初の2バイトが種類、残り1バイトがインスタンスID。この場合は種類がコントローラー、インスタンスIDが1
      hex_eoj, # DEOJ 送信先ECHNET Liteオブジェクト指定 0EF001 『ノードプロファイル』を指定
      0x62, # ESV Setl=0x60 SetC=0x61 Get=0x62
      props.size, # OPC 処理プロパティ数
      props
    ].flatten
    #raise msg.map{|v| format('0x%02X', v) }.inspect

    UDPSocket.open do |udp|
      udp.connect(node.ipaddr.to_s, 3610)
      udp.send(msg.pack('C*'), 0)
    end
  end

  def spec
    echonetlite.spec
  end

  private

  def hex_eoj
    eoj.scan(/(\w{2})(\w{2})(\w{2})/)[0].map { |v| v.to_i(16) }
  end

  def echonetlite
    device_class_code, instance_code = eoj.scan(/\A(.{4})(.{2})\z/)[0]
    @echonetlite ||= HandleMessageService::ECHONETLite::DeviceObject.new(device_class_code, instance_code, ipaddr: ipaddr, version: 'I')
  end
end
