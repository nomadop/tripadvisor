json.array!(@hotels) do |hotel|
  json.extract! hotel, :id, :name, :rating, :review_count, :location
  json.url hotel_url(hotel, format: :json)
end
