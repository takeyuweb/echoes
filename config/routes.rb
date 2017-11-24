Rails.application.routes.draw do
  resources :nodes
  resources :devices, except: %i[new create] do
    resource :setc, only: :update, controller: 'setc', module: 'devices'
  end
  root 'dashboard#index'
  post '/search' => 'dashboard#search'
end
