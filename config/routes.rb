Rails.application.routes.draw do
  root 'dashboard#index'
  post '/search' => 'dashboard#search'
end
