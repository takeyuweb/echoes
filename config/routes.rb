Rails.application.routes.draw do
  resources :devices, except: %i[new create]
  root 'dashboard#index'
  post '/search' => 'dashboard#search'
end
