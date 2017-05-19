Rails.application.routes.draw do
  devise_for :users

  scope path: ':organization_id' do
    resources :transfers, only: [:index, :create, :new, :show]
    resources :storage_locations
    resources :distributions, only: [:index, :create, :new, :show] do
      get :print, on: :member
      post :reclaim, on: :member
    end

    resources :barcode_items
    resources :dropoff_locations
    resources :items
    resources :partners

    resources :donations do
      patch :add_item, on: :member
      patch :remove_item, on: :member
      patch :complete, on: :member
    end

  end

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root "landing#index"
end
