Rails.application.routes.draw do
  resources :nodes
  resources :devices, except: %i[new create]
  root 'dashboard#index'
  post '/search' => 'dashboard#search'
end
