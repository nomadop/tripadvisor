class GeocodingApi
	MAPQUEST_APIKEY = 'Fmjtd%7Cluur206y2q%2Crw%3Do5-9ay2dy'
	BING_MAPS_APIKEY = 'Ao9yUqipvyK9Gyt1jZEiolDPDNQ4evUSSKlvUN7t0rx0iiD-u9uMNeHsojrRyNVY'
	GOOGLE_APIKEY = 'AIzaSyAXngIRBBzOVy_k9OIjEn9rW33FPCEJ6C0'

	def self.rad angle
		angle * Math::PI / 180.0
	end

	def self.get_distance lat1, lng1, lat2, lng2
		radlat1 = rad(lat1)
		radlat2 = rad(lat2)
		a = radlat1 - radlat2
		b = rad(lng1) - rad(lng2)
		s = 2 * Math.asin(Math.sqrt(Math.sin(a / 2) * Math.sin(a / 2) + Math.cos(radlat1) * Math.cos(radlat2) * Math.sin(b / 2) * Math.sin(b / 2)))
		s *= 6378.137 * 1000
		s.round(6)
	end

	def self.geocode location, api = 'mapquest'
		case api
		when 'mapquest'
			location = {location: location} if location.instance_of? String
			conn = Conn.init('http://www.mapquestapi.com')
			conn.params = location
			response = conn.get("/geocoding/v1/address?key=#{GeocodingApi::MAPQUEST_APIKEY}&inFormat=kvp&outFormat=json")
		when 'bingmaps'
			conn = Conn.init('http://dev.virtualearth.net')
			# conn.params = {
			# 	q: location,
			# 	inclnb: 0,
			# 	incl: 'queryParse,ciso2',
			# 	maxResults: 10,
			# 	key: GeocodingApi::BING_MAPS_APIKEY
			# }
			response = conn.get("/REST/v1/Locations?q=#{location}&inclnb=0&incl=queryParse,ciso2&maxResults=10&key=#{GeocodingApi::BING_MAPS_APIKEY}")
		when 'google'
			conn = Conn.init('http://maps.googleapis.com')
			conn.options.proxy = "http://127.0.0.1:8087/"
			conn.params = {
				address: location,
				sensor: false
			}
			response = conn.get('/maps/api/geocode/json')
		end
		JSON.parse(response.body)
	rescue Faraday::TimeoutError => e
		geocode(location, api)
	end

	def self.get_latlng location, api = 'mapquest'
		case api
		when 'mapquest'
			geo_res = geocode(location, api)['results']
			geo_res[0]['locations'].map { |location| location['latLng'] }
		when 'bingmaps'
			geo_res = geocode(location, api)['resourceSets']
			geo_res[0]['resources'].map do |resource|
				coord = resource['point']['coordinates']
				{'lat' => coord[0], 'lng' => coord[1]}
			end
		when 'google'
			geo_res = geocode(location, api)['results']
			geo_res[0]['geometry']['location']
		end
	end
end