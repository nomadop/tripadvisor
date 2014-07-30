class GeocodingApi
	MAPQUEST_APIKEY = 'Fmjtd%7Cluur206y2q%2Crw%3Do5-9ay2dy'
	BING_MAPS_APIKEY = 'Ao9yUqipvyK9Gyt1jZEiolDPDNQ4evUSSKlvUN7t0rx0iiD-u9uMNeHsojrRyNVY'
	GOOGLE_APIKEY = 'AIzaSyAXngIRBBzOVy_k9OIjEn9rW33FPCEJ6C0'

	def self.rad angle
		angle * Math::PI / 180.0
	end

	def self.get_distance lat1, lng1, lat2, lng2
		lat1 ||= 0.0
		lng1 ||= 0.0
		lat2 ||= 0.0
		lng2 ||= 0.0
		radlat1 = rad(lat1)
		radlat2 = rad(lat2)
		a = radlat1 - radlat2
		b = rad(lng1) - rad(lng2)
		s = 2 * Math.asin(Math.sqrt(Math.sin(a / 2) * Math.sin(a / 2) + Math.cos(radlat1) * Math.cos(radlat2) * Math.sin(b / 2) * Math.sin(b / 2)))
		s *= 6378.137 * 1000
		s.round(6)
	end

	def self.geocode location, api = 'google'
		case api
		when 'mapquest'
			# location = {location: location} if location.instance_of? String
			# conn = Conn.init('http://www.mapquestapi.com')
			# conn.params = location
			# response = conn.get("/geocoding/v1/address?key=#{GeocodingApi::MAPQUEST_APIKEY}&inFormat=kvp&outFormat=json")
			Geokit::Geocoders::MapQuestGeocoder.key = GeocodingApi::MAPQUEST_APIKEY
			Geokit::Geocoders::MapQuestGeocoder.geocode location
		when 'bingmaps'
			# conn = Conn.init('http://dev.virtualearth.net')
			# response = conn.get("/REST/v1/Locations?q=#{location}&inclnb=0&incl=queryParse,ciso2&maxResults=10&key=#{GeocodingApi::BING_MAPS_APIKEY}")
			Geokit::Geocoders::BingGeocoder.key = GeocodingApi::BING_MAPS_APIKEY
			Geokit::Geocoders::GoogleGeocoder.geocode location
		when 'google'
			# conn = Conn.init('http://maps.googleapis.com', ssl: {verify:false}, proxy: 'https://127.0.0.1:8087/')
			# conn.params = {
			# 	address: location,
			# 	sensor: false
			# }
			# response = conn.get('/maps/api/geocode/json')
			# response = conn.get(response.headers['location'])
			Geokit::Geocoders.proxy = 'https://127.0.0.1:8087/'
			Geokit::Geocoders::GoogleGeocoder.geocode location
		when 'geonames'
			Geokit::Geocoders::GeonamesGeocoder.key = GeocodingApi::GEONAMES_APIKEY
			Geokit::Geocoders::GeonamesGeocoder.premium = false
			Geokit::Geocoders::GeonamesGeocoder.geocode location
		end
		# JSON.parse(response.body)
	rescue Faraday::TimeoutError => e
		geocode(location, api)
	end

	def self.get_latlng location, api = 'bingmaps'
		loc = geocode(location, api)
		{'lat' => loc.lat, 'lng' => loc.lng}
	end
end