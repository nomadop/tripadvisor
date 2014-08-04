Rails.application.routes.draw do
  resources :cities

  resources :tasks do
    member do
      get 'log'
      post 'run'
      post 'clear_log'
    end
  end

  resources :reviews

  resources :hotels do
    collection do
      post 'update_or_create_hotels_by_country_name_from_tripadvisor'
      post 'update_or_create_hotels_from_asiatravel_by_country_code'
      post 'update_or_create_hotel_by_hotel_infos_from_asiatravel'
      post 'match_hotels_between_tripadvisor_and_asiatravel_by_country'
      get 'api'
    end
  end

  root 'home#index'
  get 'home/send_mail'
  get 'home/test_faye'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
