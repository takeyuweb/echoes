class Devices::SetcController < ApplicationController

  def put
    @device = Device.find(params[:device_id])
    epc_params = params.require(:device).permit(:epc, :edt)
    @device.set_c([epc_params[:epc].to_i(16), 0x01, epc_params[:edt].to_i(16)])
  end

end
