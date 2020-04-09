Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  use_doorkeeper

  namespace :oauth, { defaults: {format: :json} } do
    get 'device_flow_init', to: 'device_flow#init'
    get 'device_flow_authorize', to: 'device_flow#authorize'
  end

  namespace :api, { defaults: {format: :json} } do
    namespace :v1 do
      get 'user', to: 'user#show'

      resources :courses, param: :name, only: [:index, :create] do

        resources :course_user_data, only: [:index, :create, :show, :update, :destroy],
          param: :email, :constraints => { :email => /[^\/]+/ }

        resources :assessments, param: :name, only: [:index, :show] do
          get 'problems'
          get 'writeup'
          get 'handout'
          post 'submit'
          
          resources :submissions, param: :version, only: [:index] do
            get 'feedback'
          end
        end
      end

      match "*path", to: "base_api#render_404", via: :all
    end
  end

  root "courses#index"

  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks",
                                    registrations:      "registrations" },
                     path_prefix: "auth"

  get "contact", to: "home#contact"

  namespace :home do
    if Rails.env == "development" || Rails.env == "test"
      match "developer_login", via: [:get, :post]
    end
    get "error"
    get "error_404"
    get "no_user"
  end

  # device_flow-related
  get "activate", to: "device_flow_activation#index", as: :device_flow_activation
  get "device_flow_resolve", to: "device_flow_activation#resolve"
  get "device_flow_auth_cb", to: "device_flow_activation#authorization_callback"

  resource :admin do
    match "email_instructors", via: [:get, :post]
  end

  resources :users do
    get "admin"
  end

  resources :courses, param: :name do
    resources :schedulers do
        get "visualRun", action: :visual_run
        get "run"
    end

    resources :jobs, only: :index do
      get "getjob", on: :member

      collection do
        get "tango_status"
        get "tango_data"
      end
    end
    resources :announcements, except: :show
    resources :attachments

    resources :assessments, param: :name, except: :update do
      resource :autograder, except: [:new, :show]
      resources :assessment_user_data, only: [:edit, :update]
      resources :attachments
      resources :extensions, only: [:index, :create, :destroy]
      resources :groups, except: :edit do
        member do
          post "add"
          post "join"
          post "leave"
        end

        post "import", on: :collection
      end
      resources :problems, except: [:index, :show]
      resource :scoreboard, except: [:new] do
        get "help", on: :member
      end
      resources :submissions do
        resources :annotations, only: [:create, :update, :destroy]
        resources :scores, only: [:create, :show, :update]

        member do
          get "destroyConfirm"
          get "download"
          get "view"
        end

        collection do
          get "downloadAll"
          get "missing"
        end
      end

      member do
        match "bulkGrade", via: [:get, :post]
        post "bulkGrade_complete"
        get "bulkExport"
        get "releaseAllGrades"
        get "releaseSectionGrades"
        get "viewFeedback"
        get "reload"
        get "statistics"
        get "withdrawAllGrades"
        get "export"
        patch "edit/*active_tab", action: :update
        get "edit/*active_tab", action: :edit
        post "handin"
        get "history"
        get "viewGradesheet"
        get "writeup"
        get "handout"

        # autograde actions
        post "autograde_done"
        post "regrade"
        post "regradeBatch"
        post "regradeAll"

        # SVN actions
        get "admin_svn"
        post "import_svn"
        post "set_repo"

        # gradesheet ajax actions
        post "quickSetScore"
        post "quickSetScoreDetails"
        get "quickGetTotal"
        get "score_grader_info"
        get "submission_popover"

        # remote calls
        match "local_submit", via: [:get, :post]
        get "log_submit"
      end

      collection do
        get "installAssessment"
        post "importAssessment"
        post "importAsmtFromTar"
      end
    end

    resources :course_user_data do
      resource :gradebook, only: :show do
        get "bulkRelease"
        get "csv"
        get "invalidate"
        get "statistics"
        get "student"
        get "view"
      end

      member do
        get "destroyConfirm"
        match "sudo", via: [:get, :post]
        get "unsudo"
      end
    end

    member do
      get "bulkRelease"
      get "downloadRoster"
      match "email", via: [:get, :post]
      get "manage"
      get "moss"
      get "reload"
      match "report_bug", via: [:get, :post]
      post "runMoss"
      get "sudo"
      match "uploadRoster", via: [:get, :post]
      get "userLookup"
      get "users"
    end
  end
end