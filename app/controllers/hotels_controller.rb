class HotelsController < ApplicationController
  before_action :set_hotel, only: [:show, :edit, :update, :destroy]

  def api
  end

  def update_or_create_hotel_by_hotel_infos_from_asiatravel
    begin
      hotel_infos = JSON.parse(params[:hotels])
      hotels = hotel_infos.map do |hotel_info|
        Hotel.create_hotel_by_hotel_info_from_asiatravel(hotel_info)
      end
      render json: hotels
    rescue Exception => e
      render json: { error: e }
    end
  end

  def update_or_create_hotels_by_country_name_from_tripadvisor
    begin
      ignore_citys = params[:igncts] ? params[:igncts] : []
      hotels = Hotel.update_or_create_hotels_by_country_name_from_tripadvisor(params[:cname], params[:review], ignore_citys)

      render json: hotels
    rescue Exception => e
      render json: { error: e }
    end
  end

  def update_or_create_hotels_from_asiatravel_by_country_code
    begin
      hotels = Hotel.update_or_create_hotels_from_asiatravel_by_country_code(params[:code])
      render json: hotels
    rescue Exception => e
      render json: { error: e }
    end
  end

  # GET /hotels
  # GET /hotels.json
  def index
    params[:page] ||= 1
    params[:per_page] ||= 100
    if params[:city]
      @hotels = Hotel.includes(:reviews).city(params[:city]).page(params[:page]).per(params[:per_page])
    else
      @hotels = Hotel.includes(:reviews).page(params[:page]).per(params[:per_page])
    end
  end

  # GET /hotels/1
  # GET /hotels/1.json
  def show
  end

  # GET /hotels/new
  def new
    @hotel = Hotel.new
  end

  # GET /hotels/1/edit
  def edit
  end

  # POST /hotels
  # POST /hotels.json
  def create
    @hotel = Hotel.new(hotel_params)

    respond_to do |format|
      if @hotel.save
        format.html { redirect_to @hotel, notice: 'Hotel was successfully created.' }
        format.json { render :show, status: :created, location: @hotel }
      else
        format.html { render :new }
        format.json { render json: @hotel.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /hotels/1
  # PATCH/PUT /hotels/1.json
  def update
    respond_to do |format|
      if @hotel.update(hotel_params)
        format.html { redirect_to @hotel, notice: 'Hotel was successfully updated.' }
        format.json { render :show, status: :ok, location: @hotel }
      else
        format.html { render :edit }
        format.json { render json: @hotel.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /hotels/1
  # DELETE /hotels/1.json
  def destroy
    @hotel.destroy
    respond_to do |format|
      format.html { redirect_to hotels_url, notice: 'Hotel was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_hotel
      @hotel = Hotel.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def hotel_params
      params.require(:hotel).permit(:name, :rating, :review_count, :location)
    end
end
