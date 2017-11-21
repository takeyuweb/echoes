require 'ipaddr'

class HandleMessageService < ApplicationService
  module ECHONETLite
    class Instance
      class << self
        def el_objects
          raise NotImplementedError
        end
      end

      attr_reader :code, :number, :ipaddr, :properties

      def initialize(code, number, epcs: {}, ipaddr:)
        @code = normalize_code(code)
        @number = normalize_number(number)
        @epcs = epcs
        @ipaddr = normalize_ipaddr(ipaddr)

        decode_properties
      end

      def known?
        !el_object.nil?
      end

      def unknown?
        !known?
      end

      def name
        if known?
          "#{el_object['objectName']} #{number}"
        else
          nil
        end
      end

      private

      def normalize_code(code)
        "0x#{code.upcase}".freeze
      end

      def normalize_number(number)
        case number
          when String
            number.to_i(16)
          else
            number.to_i
        end
      end

      def normalize_ipaddr(ipaddr)
        case ipaddr
          when IPAddr
            ipaddr
          else
            IPAddr.new(ipaddr)
        end
      end

      def el_object
        @el_object ||= self.class.el_objects[code]
      end

      def decode_properties
        @properties =
          @epcs.keys.map do |epc|
            edt = @epcs[epc]
            epc = normalize_code(epc)
            decode_property(edt, el_object['epcs'][epc])
          end
      end

      def decode_property(edt, spec)
        edt = edt.dup
        spec['epcName']
        spec['epcSize']
        spec['notApplicable'] # 適応外
        spec['accessModeSet'] # Set時必須 required / optional / notApplicable
        spec['accessModeGet'] # Get時必須 required / optional / notApplicable
        spec['accessModeAnno'] # 状変アナウンス時必須 required / optional / notApplicable
        spec['edt'].each do |element|
          element['elementName']
          element['elementSize']
          element['repeatCount']
          element['content']
          element['content']['keyValues'] # 個々の数値にそれぞれ意味を持たせた場合。例: 0x30=ON
          element['content']['numericValue'] # 数値の場合。例: 25%
          element['content']['level'] # 制御のレベルをある範囲の値に対応させた場合。例: 0x31->レベル1, ... 0x38->レベル8
          element['content']['bitmap'] # bit毎に動作設定を定義した場合。
          element['content']['rawData'] # 数値としてではなく、値そのものを利用する場合。例: 製造番号
          element['content']['customType'] # 複数のnumericValueの組み合わせで特定の意味を持つ場合。例: 年月日, 日時
          element['content']['others'] # その他の場合。例: 特定のEPC固有のdecode方法を持つ場合。
          element['repeatCount'].times do
            content = edt.slice!(0, element['elementSize'])
            if element['content'].has_key?('numericValue')
              decimal
              content_code = normalize_code(content).inspect
              raise element['content'].inspect
              if element['content'].has_key?('keyValues')
                content_code = normalize_code(content).inspect
                if element['content']['keyValues'].has_key?(content_code)
                  element['content']['keyValues'][content_code]
                else

                end
              else

              end
              raise element['content'].inspect
            elsif element['content'].has_key?('level')
              raise element['content'].inspect
            elsif element['content'].has_key?('bitmap')
              raise element['content'].inspect
            elsif element['content'].has_key?('rawData')
              raise element['content'].inspect
            elsif element['content'].has_key?('customType')
              raise element['content'].inspect
            elsif element['content'].has_key?('others')
              Rails.logger.debug "#{spec['epcName']}(#{element['elementName']}): #{content}"
            end
          end
        end
      end
    end

    class NodeProfile < Instance
      class << self
        def el_objects
          JSON.parse(File.read(Rails.root.join('config', 'appendix', "nodeProfile.json")))['elObjects']
        end
      end
    end

    class DeviceObject < Instance
      class << self
        def el_objects
          JSON.parse(File.read(Rails.root.join('config', 'appendix', "deviceObject.json")))['elObjects']
        end
      end
    end

    class Frame
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
        hexstring = hexstring.dup
        opc.to_i(16).times.inject({}) do |memo, _|
          epc = hexstring.slice!(0, 2)
          pdc = hexstring.slice!(0, 2)
          edt = hexstring.slice!(0, pdc.to_i(16) * 2)
          memo.tap { |m| m[epc] = edt }
        end
      end
    end

    def self.get_instance(echonetobject, epcs: {}, ipaddr:)
      device_class_code, instance_code = echonetobject.scan(/\A(.{4})(.{2})\z/)[0]
      if device_class_code =~ /\A0ef0\z/i
        NodeProfile.new(device_class_code, instance_code, epcs: epcs, ipaddr: ipaddr)
      else
        DeviceObject.new(device_class_code, instance_code, epcs: epcs, ipaddr: ipaddr)
      end
    end
  end

  def call(bytes, address_info)
    Rails.logger.info "Received: #{bytes.chomp.unpack('H*')} from #{address_info[3]}"

    frame = ECHONETLite::Frame.new(bytes)
    Rails.logger.info "Parsed: #{frame.inspect}"
    echonetinstance = ECHONETLite.get_instance(frame[:SEOJ], epcs: frame[:DETAILS], ipaddr: address_info[3])
    Rails.logger.info "#{echonetinstance.name} from #{echonetinstance.ipaddr}"
    Rails.logger.info echonetinstance.properties.inspect
  end
end