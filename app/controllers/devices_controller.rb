class DevicesController < ApplicationController
  before_action :set_device, only: [:show, :edit, :update, :destroy]

  # GET /devices
  # GET /devices.json
  def index
    @devices = Device.all
  end

  # GET /devices/1
  # GET /devices/1.json
  def show
    @device.get([0x80, 0x01, 0x00])
  end

  # GET /devices/1/edit
  def edit
  end

  # PATCH/PUT /devices/1
  # PATCH/PUT /devices/1.json
  def update
    # FIXME: コード整理
    epc_params = params.require(:device).permit(:epc, :edt)
    if epc_params.present?
      @device.set_c([epc_params[:epc].to_i(16), 0x01, epc_params[:edt].to_i(16)])

      respond_to do |format|
        format.html { redirect_to @device, notice: 'Device was successfully updated.' }
        format.json { render :show, status: :ok, location: @device }
      end
    else
      respond_to do |format|
        if @device.update(device_params)
          format.html { redirect_to @device, notice: 'Device was successfully updated.' }
          format.json { render :show, status: :ok, location: @device }
        else
          format.html { render :edit }
          format.json { render json: @device.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /devices/1
  # DELETE /devices/1.json
  def destroy
    @device.destroy
    respond_to do |format|
      format.html { redirect_to devices_url, notice: 'Device was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_device
      @device = Device.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def device_params
      params.require(:device).permit(:name)
    end
end
