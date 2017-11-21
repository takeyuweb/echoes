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

      def initialize(code, number, epcs: {}, ipaddr: nil)
        @code = normalize_code(code)
        @number = normalize_number(number)
        @epcs = normalize_epcs(epcs)
        @ipaddr = normalize_ipaddr(ipaddr)

        decode_properties
      end

      def eoj
        code.scan(/0x(\w{2})(\w{2})/)[0].map { |v| v.to_i(16) } + [number]
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
          when String
            IPAddr.new(ipaddr)
          else
            nil
        end
      end

      def normalize_epcs(epcs)
        epcs.inject({}) do |memo, pair|
          epc, edt = pair
          memo[normalize_code(epc)] = edt
          memo
        end
      end

      def el_object
        self.class.el_objects[code]
      end

      def decode_properties
        @properties =
          @epcs.inject({}) do |memo, pair|
            epc, edt = pair
            if el_object['epcs'][epc]
              memo[el_object['epcs'][epc]['epcName']] = decode_property(edt, el_object['epcs'][epc])
            else
              Rails.logger.debug el_object.inspect
              Rails.logger.debug "Unknown EPC: #{epc} (#{name})"
            end
            memo
          end
      end

      def decode_property(edt, spec)
        data = {}
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
          data[element['elementName']] =
            Array.new(element['repeatCount']) do
              element_data = {}
              content = edt.slice!(0, element['elementSize'] * 2)
              if element['content'].has_key?('numericValue')
                if element['content'].has_key?('keyValues')
                  content_code = normalize_code(content).inspect
                  if element['content']['keyValues'].has_key?(content_code)
                    element_data['keyValue'] = element['content']['keyValues'][content_code]
                  end
                end
                # TODO: Unsigned / Signed のサポート
                element_data['numericValue'] = content.to_i(16)
              elsif element['content'].has_key?('level')
                raise element['content'].inspect
              elsif element['content'].has_key?('bitmap')
                raise element['content'].inspect
              elsif element['content'].has_key?('rawData')
                raise element['content'].inspect
              elsif element['content'].has_key?('customType')
                raise element['content'].inspect
              elsif element['content'].has_key?('others')
                element_data['others'] = element['content']['others']
              end
              element_data['raw'] = content
              element_data
            end
        end
        data
      end
    end

    class NodeProfile < Instance
      class << self
        def el_objects
          JSON.parse(File.read(Rails.root.join('config', 'appendix', "nodeProfile.json")))['elObjects']
        end
      end

      attr_reader :instances

      def initialize(*args)
        @instances = []
        super(*args)
      end

      private

      def decode_properties
        super

        if property = properties['Version情報']
          # 対応するAPPENDIX の Release 順を1バイトのASCIIコードで示す
          # 1バイト目、2バイト目は将来拡張用として 0x00固定
          # 3バイト目がRelease順を示す
          #   Release B 0x00 0x00 0x42 0x00
          raise property['Version情報'][0]['raw'].inspect
          raise property['Version情報'][0]['raw'].slice(4, 2).to_i(16).chr
        end

        if property = properties['自ノードインスタンスリストS']
          if property['インスタンス総数'][0].has_key?('keyValue') &&
            property['インスタンス総数'][0]['keyValue'] == 'Overflow'
            # TODO: インスタンス総数が 255以上の場合
            raise property.inspect
          else
            raw = property['インスタンスリスト'][0]['raw']
            Array.new(property['インスタンス総数'][0]['numericValue']) do
              object_code = raw.slice!(0, 6) # EOJ 3bytes
              add_instace(object_code)
            end
          end
        end
      end

      def add_instace(echonetobject)
        @instances.push(ECHONETLite.get_instance(echonetobject))
      end
    end

    class DeviceObject < Instance
      class << self
        APPENDIX_RELEASE = %w(G H I).freeze
        def el_objects(version)
          # FIXME: 見つからないときはとりあえず一番新しいのを
          version = APPENDIX_RELEASE.include?(version) ? version : APPENDIX_RELEASE.last

          el_superclass_object = JSON.parse(File.read(Rails.root.join('config', 'appendix', version, 'superClass.json')))['elObjects']['0x0000']
          JSON.parse(File.read(Rails.root.join('config', 'appendix', version, 'deviceObject.json')))['elObjects'].inject({}) do |memo, pair|
            code, el_object = pair
            memo[code] = el_object
            memo[code]['epcs'] = el_superclass_object['epcs'].merge(memo[code]['epcs'])
            memo
          end
        end
      end

      attr_reader :version

      private

      def decode_version
        if @epcs['0x82']
          @version = @epcs['0x82'].slice(4, 2).to_i(16).chr
        else
          @version = nil
        end
      end

      def decode_properties
        # デバイスプロファイルはAPPENDIXバージョンを特定できないとプロパティ解析できない
        # まずバージョンを確認
        decode_version
        # これで機器オブジェクト詳細規定を特定できるので解析に進める
        super if version
      end

      def el_object
        self.class.el_objects(version)[code]
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

    def self.get_instance(echonetobject, epcs: {}, ipaddr: nil)
      device_class_code, instance_code = echonetobject.scan(/\A(.{4})(.{2})\z/)[0]
      if device_class_code.match?(/\A0ef0\z/i)
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
    Rails.logger.info echonetinstance.inspect

    if echonetinstance.respond_to?(:instances)
      ReceiveMessageJob.perform_later(3)

      echonetinstance.instances.each do |instance|
        Rails.logger.info instance.inspect

        # すべてノードに対して，ノードプロファイルを要求する
        bytes = [
          0x10, # EHD1 固定
          0x81, # EHD2 固定
          0x00, 0x00, # TID
          0x05, 0xFF, 0x01, # SEOJ 送信元ECHONET Liteオブジェクト指定 最初の2バイトが種類、残り1バイトがインスタンスID。この場合は種類がコントローラー、インスタンスIDが1
          instance.eoj, # DEOJ 送信先ECHNET Liteオブジェクト指定 0EF001 『ノードプロファイル』を指定
          0x62, # ESV Setl=0x60 SetC=0x61 Get=0x62
          0x01, # OPC 処理プロパティ数
          0x82, # EPC1 Version情報=0x82
          0x00, # EDT1
        ]
        msg = bytes.flatten.pack('C*')

        UDPSocket.open do |udp|
          udp.connect(echonetinstance.ipaddr.to_s, 3610)
          udp.send(msg, 0)
        end
      end
    end
  end
end