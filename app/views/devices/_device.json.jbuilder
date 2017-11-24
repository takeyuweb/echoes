json.extract! device, :id, :name, :ipaddr, :eoj, :created_at, :updated_at
json.url device_url(device, format: :json)
json.specs device.spec do |epc, epc_info|
  json.epc epc
  json.edt epc_info['edt']
end
