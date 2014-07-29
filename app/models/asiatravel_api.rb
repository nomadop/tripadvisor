# -*- encoding : utf-8 -*-
class AsiatravelApi
  HEADERS = 
  {
    # "SOAPHeaderAuthentication" => 
    # {
    #   "UserName"=>"sense_xml",
    #   "Culture"=>"zh-CN", 
    #   "Password"=>"sense11"
    # }
    "SOAPHeaderAuthentication" => 
    {
      "UserName"=>"sense_xml",
      "Culture"=>"zh-CN", 
      "Password"=>"Sense12"
    }
  }
  HEADERS_PRODUCTION = 
  {
    "SOAPHeaderAuthentication" => 
    {
      "UserName"=>"sense_xml",
      "Culture"=>"zh-CN", 
      "Password"=>"Sense12"
    }
  }

  YOUDAO =
  {
    'keyfrom'=>'senscape',
    'key'=>'1261741802'
  }
# (ENV['push_server_url'], {"production" =>false , "token"=>user.device_token,"message"=>{"aps"=>{"alert" =>"语音许愿消息"}, "media_url"=>"#{ENV['host']}/uploads/media/audio/#{wechat.media_id}.amr",'user_id'=>user.id, 'wechat_id'=> wechat.id}}.to_json)

  def self.init_iso_data(token, media_url, wechat_id, user_id)
   {"production" =>false , "token"=> token,"message"=>{"aps"=>{"alert" =>"语音许愿消息"}, "media_url"=>media_url,'user_id'=>user_id, 'wechat_id'=> wechat_id}}.to_json
  end
  def self.init_android_data(token, media_url, wechat_id, user_id, content = '语音许愿消息')
    {
      'signature' => Digest::MD5.hexdigest(content).upcase,
      'appkey' => ENV['android_appkey'],
      'params' => {
        'msg_content' => content,
        'msg_title' => content,
        'msg_type' => '1',
        'registration_id' => token,
        'time_to_live' => 864000,
        'msg_extras' => {
          'media_url' => media_url,
          'wechat_id' => wechat_id,
          'user_id' => user_id,
        }
      }
    }.to_json
  end
  def self.push_data_to_push_server(token, media_url, wechat_id, user_id, device_type)
    conn = AsiatravelApi.init_conn
    conn.headers["Accept"]="text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    conn.headers["Accept-Language"] = "null"
    conn.headers["Accept-Encoding"] = "gzip, deflate"
    conn.headers["Content-Type"] =  "application/json; charset=UTF-8"
    conn.headers["Connection"] = 'keep-alive'
    conn.headers["Pragma"] = "no-cache"
    conn.headers["Cache-Control"] = "no-cache"
    if device_type == 'android'
      conn.post(ENV['push_android_server_url'], AsiatravelApi.init_android_data(token, media_url, wechat_id, user_id))
    else
      conn.post(ENV['push_server_url'], AsiatravelApi.init_iso_data(token, media_url, wechat_id, user_id))
    end
  end

  def self.push_data_to_android_push_server(url, post_data)
  end

  def self.translate_by_youdao content
    begin
      url = "http://fanyi.youdao.com/openapi.do?keyfrom=#{AsiatravelApi::YOUDAO['keyfrom']}&key=#{AsiatravelApi::YOUDAO['key']}&type=data&doctype=json&version=1.1&q=#{ URI.encode(content)}"
      JSON.parse(open(url).string)["web"][0]["value"][0]
    rescue Exception => e
      ""
    end
  end

  def self.translate_by_google content
    begin
      url = "http://translate.google.cn//translate_a/t?client=t&sl=en&tl=zh-CN&hl=zh-CN&sc=2&ie=UTF-8&oe=UTF-8&ssel=0&tsel=0&q=#{content.gsub(' ','%20')}" 
      /\p{Han}+/.match(open(url).string).to_s
    rescue Exception => e
      ""
    end  
  end
  
  def self.init_conn 
    conn = Faraday.new(:url => 'https://api.weixin.qq.com') do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      # faraday.use :cookie_jar
    end
    conn.headers["User-Agent"]='Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:11.0) Gecko/20100101 Firefox/11.0'
    return conn
  end 

  def self.check_notify_verify params
    begin

      url = "https://mapi.alipay.com/gateway.do?service=notify_verify&partner=#{ENV['PID']}&notify_id=#{params['notify_id']}"
      open(url).string == "true"
    rescue Exception => e
      return false
    end
  end

  def self.md5(params)
    Digest::MD5.hexdigest(self.params_to_url(params)+ENV["KEY"])
  end
  def self.sha1(str)   
    Digest::SHA1.hexdigest(str)   
  end  

  def self.params_to_url(params)
    params = params.sort
    res = ""
    params.each do |unit|
      res+=unit[0] + "=" + unit[1] +"&"
    end
    res=res[0...res.size-1]
    res
  end
  def self.init_all
    
    Country.init;
    City.init;
    Hotel.init_hotels_by_country_city_code("SG","SIN")
    Hotel.init_hotels_by_country_city_code("HK","HKG")
    User.update_wechat_user_info
    # Room.update_hotels_room_info_by_date
    # (1..5).each do |people|
    #   Room.update_room_rates_info_by_date(people)
    # end
  end

  def self.get_client()
    require 'savon'
    # wsdl = 'http://ws.asiatravel.net/HotelB2BAPI/atHotelsService.asmx?WSDL'
    wsdl='http://packages.asiatravel.com/agentws/ATHotelsService.asmx?WSDL' #production
    client = Savon.client(wsdl: wsdl)
  end

  def self.book_hotel(message)
    begin
      client = AsiatravelApi.get_client()
      response = client.call(
              :book_hotel, 
              :soap_header=>AsiatravelApi::HEADERS,
              :message=>message,
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
              )
      return response.body[:book_hotel_response][:book_hotel_result][:diffgram][:at_booking_details][:booking]
    rescue Exception => e
      return false
    end
  end

  def self.retreive_booking(reference_no)
    client = AsiatravelApi.get_client()
    response = client.call(
            :retreive_booking, 
            :soap_header=>AsiatravelApi::HEADERS,
            :message=>{
              ReferenceNo:reference_no
              },
            :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
  end

  def self.cancel_booking(reference_no)
    client = AsiatravelApi.get_client()
    response = client.call(
            :cancel_booking, 
            :soap_header=>AsiatravelApi::HEADERS,
            :message=>{
              ReferenceNo:reference_no
              },
            :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
  end

  def self.get_cancellation_fee(reference_no)
    client = AsiatravelApi.get_client()
    response = client.call(
            :get_cancellation_fee, 
            :soap_header=>AsiatravelApi::HEADERS,
            :message=>{
              ReferenceNo:reference_no
              },
            :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
  end

  def self.get_country_list(culture ='zh-CN')
    begin
      client = AsiatravelApi.get_client()
      soap_header = AsiatravelApi::HEADERS
      soap_header['SOAPHeaderAuthentication']['Culture'] = culture
      response = client.call(
              :get_country_list, 
              :soap_header=>soap_header,
              :message=>{},
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
              )
      response.body[:get_country_list_response][:get_country_list_result][:diffgram][:at_country_list][:country]
    rescue Exception => e
      return []
    end
  end

  def self.get_city_list_by_country_code(country_code, culture='zh-CN')
    begin
      client = AsiatravelApi.get_client()
      soap_header = AsiatravelApi::HEADERS
      soap_header['SOAPHeaderAuthentication']['Culture'] = culture
      response = client.call(
              :get_city_list_by_country_code, 
              :soap_header=>soap_header, 
              :message=>
                {
                  CountryCode:country_code
                },
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
      begin
        cities = response.body[:get_city_list_by_country_code_response][:get_city_list_by_country_code_result][:diffgram][:at_city_list][:city]
      rescue Exception => e
        cities = []
      end
      if cities.class.to_s == "Hash"
        cities = [cities]
      end  
      return cities
    rescue Exception => e
      return []
    end
  end

  def self.get_hotel_list_by_country_city_code(country_code, city_code)
    begin
      client = AsiatravelApi.get_client()
      response = client.call(
              :get_hotel_list_by_country_city_code, 
              :soap_header=>AsiatravelApi::HEADERS, 
              :message=>
                {
                  CountryCode:country_code,
                  CityCode:city_code
                },
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
      begin
        hotels = response.body[:get_hotel_list_by_country_city_code_response][:get_hotel_list_by_country_city_code_result][:diffgram][:hotel_list][:hotel]
      rescue Exception => e
        hotels = []  
      end
      if hotels.class.to_s == "Hash"
        hotels = [hotels]
      end  
      return hotels
    rescue Exception => e
      return []
    end
    
   end

  def self.retrieve_hotel_information(hotel_code)
    begin
      client = AsiatravelApi.get_client()
      response = client.call(
              :retrieve_hotel_information, 
              :soap_header=>AsiatravelApi::HEADERS, 
              :message=>
                {
                  intHotelID:hotel_code,
                },
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
      begin
        hotel = response.body[:retrieve_hotel_information_response][:retrieve_hotel_information_result][:diffgram][:at_hotel_details]
      rescue Exception => e
        hotel = nil
      end
      return hotel
    rescue Exception => e
      return false
    end
  end

  def self.retrieve_hotel_information_v2(hotel_code)
    begin
      client = AsiatravelApi.get_client()
      response = client.call(
              :retrieve_hotel_information_v2, 
              :soap_header=>AsiatravelApi::HEADERS, 
              :message=>
                {
                  intHotelID:hotel_code,
                },
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
      begin
        hotel = response.body[:retrieve_hotel_information_v2_response][:retrieve_hotel_information_v2_result][:diffgram][:at_hotel_details]
      rescue Exception => e
        hotel = nil
      end
      return hotel
    rescue Exception => e
      return false
    end
    
  end



  # AsiatravelApi.search_hotels_by_dest("SG","SIN","2013-11-27","2013-11-28",3,3,0,false)
  # return hotels 
  # hotel [:hotel_code, :hotel_name, :star_rating, :category, :address, :location, 
  #   :postal_code, :city, :country, :hotel_desc, :avg_price, :front_pg_image, 
  #   :availability, :is_best_deal, :hotel_review_score, :hotel_review_count, 
  #   :room, :"@diffgr:id", :"@msdata:row_order"]
  def self.search_hotels_by_dest(country_code, city_code, check_in_date, check_out_date, no_of_room, no_of_adult, no_of_child = 0, all_occupancy=false)
    begin
      client = AsiatravelApi.get_client
      response = client.call(
              :search_hotels_by_dest, 
              :soap_header=>AsiatravelApi::HEADERS, 
              message:
              {
                CountryCode:country_code,
                CityCode:city_code,
                CheckIndate:check_in_date,
                CheckoutDate:check_out_date,
                NoOfRoom:no_of_room,
                NoOfAdult:no_of_adult,  
                NoOfChild:no_of_child,
                AllOccupancy:all_occupancy,
              },
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
      begin
        hotels = response.body[:search_hotels_by_dest_response][:search_hotels_by_dest_result][:diffgram][:at_hotel_list][:hotel]
      rescue Exception => e
        hotels = []
      end
      unless hotels
        hotels =[]
      end
      return hotels
    rescue Exception => e
      return []
    end
    
  end

  def self.search_hotels_by_dest_v2_with_xml(country_code, city_code, check_in_date, check_out_date, room_search_info, instant_confirmation_only = true)
    conn = AsiatravelApi.init_conn
    conn.headers['Content-Type'] = "text/xml; charset=utf-8"
    url = "http://packages.asiatravel.com/agentws/ATHotelsService.asmx" 
    xml =  "<?xml version=\"1.0\" encoding=\"UTF-8\"?><env:Envelope xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:tns=\"http://instantroom.com/\" xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\"><env:Header><SOAPHeaderAuthentication xmlns=\"http://instantroom.com/\"><UserName>#{AsiatravelApi::HEADERS_PRODUCTION['SOAPHeaderAuthentication']['UserName']}</UserName><Culture>#{AsiatravelApi::HEADERS_PRODUCTION['SOAPHeaderAuthentication']['Culture']}</Culture><Password>#{AsiatravelApi::HEADERS_PRODUCTION['SOAPHeaderAuthentication']['Password']}</Password></SOAPHeaderAuthentication></env:Header><env:Body><tns:SearchHotelsByDestV2 xmlns=\"http://instantroom.com/\"><CountryCode>#{country_code}</CountryCode><CityCode>#{city_code}</CityCode><CheckIndate>#{check_in_date}</CheckIndate><CheckoutDate>#{check_out_date}</CheckoutDate><RoomInfo><RoomSearchInfo>#{room_search_info}</RoomSearchInfo></RoomInfo><InstantConfirmationOnly>#{instant_confirmation_only}</InstantConfirmationOnly></tns:SearchHotelsByDestV2></env:Body></env:Envelope>" 
    time1 = Time.now
    response  = conn.post(url, xml).body
    time2 = Time.now
    response = Nokogiri::XML(response)
    time3 = Time.now
    p "asiatravel time used #{(time2 - time1).to_i}"
    p "Nokogiri time used #{(time3 - time2).to_i}"
    response
  end

  # AsiatravelApi.search_hotels_by_dest_v2("SG","SIN","2013-12-28","2013-12-30",[{NoAdult:1,NoChild:0,"ChildAge"=>{"int" =>[]}}],true)
  def self.search_hotels_by_dest_v2(country_code, city_code, check_in_date, check_out_date, room_search_info, instant_confirmation_only = true)
    begin
      client = AsiatravelApi.get_client
      response = client.call(
              :search_hotels_by_dest_v2, 
              :soap_header=>AsiatravelApi::HEADERS, 
              message:
              {
                CountryCode:country_code,
                CityCode:city_code,
                CheckIndate:check_in_date,
                CheckoutDate:check_out_date,
                RoomInfo:
                {
                  "RoomSearchInfo"=>room_search_info
                },
                InstantConfirmationOnly:instant_confirmation_only
              },
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
      return response
      begin
        hotels = response.body[:search_hotels_by_dest_v2_response][:search_hotels_by_dest_v2_result][:diffgram][:at_hotel_list][:hotel]
      rescue Exception => e
        p e
        hotels =[]
      end
      unless hotels
        hotels =[]
      end
      return hotels
    rescue Exception => e
      return []
    end
    
  end

#AsiatravelApi.search_hotel_by_hotel_id(10,"2013-11-25","2013-11-26",3,3,0,false,false)
# return hotel
#[:hotel_code, :hotel_name, :star_rating, :address, :location, :postal_code, :city, :country, :avg_price, :front_pg_image, :availability, 
#:is_best_deal, :room, :"@diffgr:id", :"@msdata:row_order"]
  def self.search_hotel_by_hotel_id(hotel_id, check_in_date, check_out_date, no_of_room, no_of_adult, no_of_child = 0, all_occupancy=false, instant_confirmation_only = false)
    begin
      client = AsiatravelApi.get_client
      response = client.call(
              :search_hotel_by_hotel_id, 
              :soap_header=>AsiatravelApi::HEADERS, 
              message:
              {
                HotelID:hotel_id,
                CheckInDate:check_in_date,
                CheckOutDate:check_out_date,
                NoOfRoom:no_of_room,
                NoOfAdult:no_of_adult,  
                NoOfChild:no_of_child,
                AllOccupancy:all_occupancy,
                InstantConfirmationOnly:instant_confirmation_only
              },
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
      begin
        hotel = response.body[:search_hotel_by_hotel_id_response][:search_hotel_by_hotel_id_result][:diffgram][:at_hotel_list][:hotel]
      rescue Exception => e
        hotel = nil
      end
      return hotel
    rescue Exception => e
      return false
    end
    
  end

#AsiatravelApi.search_hotel_by_hotel_id_v2(10,"2014-02-27","2014-02-28",1,0,true)
  def self.search_hotel_by_hotel_id_v2(hotel_id, check_in_date, check_out_date, no_of_adult, no_of_child = 0, all_occupancy=false, instant_confirmation_only = false)
    begin
      client = AsiatravelApi.get_client
      response = client.call(
              :search_hotel_by_hotel_id_v2, 
              :soap_header=>AsiatravelApi::HEADERS, 
              message:
              {
                HotelID:hotel_id,
                CheckInDate:check_in_date,
                CheckOutDate:check_out_date,
                RoomInfo:{
                  "RoomSearchInfo"=>
                  {
                    NoAdult:no_of_adult,
                    NoChild:no_of_child,
                  },
                  "ChildAge"=>
                  {
                  }
                },
                InstantConfirmationOnly:instant_confirmation_only
              },
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
      begin
        hotel = response.body[:search_hotel_by_hotel_id_v2_response][:search_hotel_by_hotel_id_v2_result][:diffgram][:at_hotel_list][:hotel]
      rescue Exception => e
        hotel = nil
      end
      return hotel
    rescue Exception => e
      return false
    end
    
  end

  def self.search_hotel_by_hotel_id_and_room_search_infos_v2(hotel_id, check_in_date, check_out_date, room_search_infos, instant_confirmation_only = true)
    begin
      client = AsiatravelApi.get_client
      response = client.call(
              :search_hotel_by_hotel_id_v2, 
              :soap_header=>AsiatravelApi::HEADERS, 
              message:
              {
                HotelID:hotel_id,
                CheckInDate:check_in_date,
                CheckOutDate:check_out_date,
                RoomInfo:
                    {
                      "RoomSearchInfo"=>room_search_infos
                    },
                  
                InstantConfirmationOnly:instant_confirmation_only
              },
              :attributes =>{ "xmlns"=>"http://instantroom.com/"}
            )
      begin
        hotel = response.body[:search_hotel_by_hotel_id_v2_response][:search_hotel_by_hotel_id_v2_result][:diffgram][:at_hotel_list][:hotel]
      rescue Exception => e
        hotel = nil
      end
      return hotel
    rescue Exception => e
      return false
    end
  end

end