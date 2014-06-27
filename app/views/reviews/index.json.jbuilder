json.array!(@reviews) do |review|
  json.extract! review, :id, :review_id, :hotel_id, :title, :content
  json.url review_url(review, format: :json)
end
