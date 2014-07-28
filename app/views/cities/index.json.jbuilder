json.array!(@cities) do |city|
  json.extract! city, :id, :name, :code, :country_id
  json.url city_url(city, format: :json)
end
