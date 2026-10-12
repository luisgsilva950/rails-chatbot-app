Rails.application.routes.draw do
  mount RubyLLM::Evaluations::Engine => "/evaluations" if Rails.env.development?

  get "up" => "rails/health#show", as: :rails_health_check

  resources :chats, only: %i[index show create] do
    resources :messages, only: :create
  end

  root "chats#index"
end
