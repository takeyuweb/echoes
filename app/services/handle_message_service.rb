class HandleMessageService < ApplicationService
  module EchonetLite
    class DeviceClass
      attr_reader :class_code

      def initialize(class_code)
        @class_code = class_code
        @el_object = el_objects[class_code]
      end

      def name
        @el_object['objectName']
      end

      private

      def el_objects
        device_objects = JSON.parse(File.read(Rails.root.join('config', 'appendix', 'deviceObject.json')))['elObjects']
        node_profiles = JSON.parse(File.read(Rails.root.join('config', 'appendix', "nodeProfile.json")))['elObjects']
        device_objects.merge(node_profiles)
      end
    end

    class DeviceObject
      attr_reader :device_class, :instance_code

      def initialize(class_code, instance_code)
        @device_class = DeviceClass.new(class_code)
        @instance_code = instance_code
      end

      def name
        "#{device_class.name} #{instance_number}"
      end

      def instance_number
        instance_code.to_i(16)
      end
    end

    class Data
      def initialize(bytes)
        @data = {}
        parse(bytes)
      end

      def [](key)
        key = key.to_sym
        if @data.keys.include?(key)
          @data[key.to_sym]
        else
          raise ArgumentError
        end
      end

      def device_object
        device_class_code = "0x#{self[:SEOJ][0..3].upcase}"
        device_instance_code = "0x#{self[:SEOJ][4..5].upcase}"
        DeviceObject.new(device_class_code, device_instance_code)
      end

      private

      def parse(bytes)
        if bytes.length < 14
          raise ArgumentError.new("bytes is less then 14 bytes. bytes.length is #{bytes.length}")
        end
        parse_hexstring(bytes.chomp.unpack('H*')[0])
      end

      def parse_hexstring(hexstring)
        # 電文が ECHONET Lite であることを宣言する部分
        # "1081"でない場合ECHONETではない
        raise ArgumentError unless hexstring.slice(0, 4) == '1081'

        @data[:EHD] = '1081'
        @data[:TID] = hexstring.slice(4, 4)
        @data[:SEOJ] = hexstring.slice(8, 6)
        @data[:DEOJ] = hexstring.slice(14, 6)
        @data[:EDATA] = hexstring.slice(20, hexstring.length)
        # SetI:60 SetC: 61 (応答は71) Get: 62 (応答は72)
        @data[:ESV] = hexstring.slice(20, 2)
        # 処理プロパティ数
        @data[:OPC] = hexstring.slice(22, 2)
        @data[:DETAIL] = hexstring.slice(24, hexstring.length)
        @data[:DETAILS] = parse_detail(@data[:OPC], @data[:DETAIL])
      end

      def parse_detail(opc, hexstring)
        # TODO
        {}
      end
    end
  end

  def call(bytes, address_info)
    Rails.logger.info "Received: #{bytes.chomp.unpack('H*')} from #{address_info[3]}"

    echonetlite_data = EchonetLite::Data.new(bytes)
    Rails.logger.info "Parsed: #{echonetlite_data.inspect}"
    Rails.logger.info "Parsed: #{echonetlite_data.device_object.name}"
  end
end