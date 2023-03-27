Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  use_doorkeeper
    post 'lti_launch/oidc_login', to: "lti_launch#oidc_login"
    get 'lti_launch/oidc_login', to: "lti_launch#oidc_login"
    post 'lti_launch/launch', to: "lti_launch#launch"
    get 'lti_launch/launch', to: "lti_launch#launch"
    post 'lti_nrps/sync_roster', to: "lti_nrps#sync_roster"
  get 'lti_config/index', to: "lti_config#index"
  post 'lti_config/update_config', to: "lti_config#update_config"

  namespace :oauth, { defaults: { format: :json } } do
    get "device_flow_init", to: "device_flow#init"
    get "device_flow_authorize", to: "device_flow#authorize"
  end

  namespace :api, { defaults: { format: :json } } do
    namespace :v1 do
      get "user", to: "user#show"

      resources :courses, param: :name, only: [:index, :create] do
        resources :course_user_data, only: [:index, :create, :show, :update, :destroy],
                                     param: :email, :constraints => { :email => /[^\/]+/ }
        
        resources :assessments, param: :name, only: [:index, :show] do
          resources :problems, only: [:index, :create]
          get "writeup"
          get "handout"
          post "submit"
          post "set_group_settings"
          
          resources :groups, only: [:index, :create, :destroy]

          resources :submissions, param: :version, only: [:index] do
            get "feedback"
          end

          resources :scores, only: [:index, :show],
                    param: :email, :constraints => { :email => /[^\/]+/ }

          put "scores/:email/update_latest", :constraints => { :email => /[^\/]+/ }, to: "scores#update_latest"
        end
      end

      match "*path", to: "base_api#render_404", via: :all
    end
  end

  root "courses#courses_redirect"

  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks",
                                    registrations: "registrations" },
                     path_prefix: "auth"

  get "contact", to: "home#contact"
  get "courses", to: "courses#index"

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

  resource :admin, :except => [:show] do
    match "email_instructors", via: [:get, :post]
    match "github_integration", via: [:get]
    post "clear_cache"
  end

  resources :users do
    get "admin"
    get "github_oauth", on: :member
    get "lti_launch_initialize", on: :member
    post "lti_launch_link_course", on: :member
    post "github_revoke", on: :member
    get "github_oauth_callback", on: :collection
  end

  resources :courses, param: :name do
    resources :schedulers do
      post "visualRun", action: :visual_run
      post "run"
    end

    resource :metrics, only: :index do
      get "index"
      get "get_current_metrics"
      get "get_watchlist_instances"
      get "get_num_pending_instances"
      post "refresh_watchlist_instances"
      get "get_watchlist_configuration"
      post "update_current_metrics"
      post "update_watchlist_instances"
      post "update_watchlist_configuration"
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
        resources :annotations, only: [:create, :update, :destroy] do
          collection do
            get "shared_comments"
          end
        end

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
        post "releaseAllGrades"
        post "releaseSectionGrades"
        get "viewFeedback"
        get "getPartialFeedback"
        post "reload"
        get "statistics"
        post "withdrawAllGrades"
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
        get "install_assessment"
        post "importAssessment"
        post "importAsmtFromTar"
      end
    end

    resources :course_user_data do
      resource :gradebook, only: :show do
        post "bulk_release"
        get "csv"
        post "invalidate"
        get "statistics"
        get "student"
        get "view"
      end

      member do
        get "destroyConfirm"
        match "sudo", via: [:get, :post]
        post "unsudo"
      end
    end

    member do
      post "bulk_release"
      get "download_roster"
      post "unlink_course"
      patch "update_lti_settings"
      match "email", via: [:get, :post]
      get "manage"
      get "moss"
      post "reload"
      match "report_bug", via: [:get, :post]
      post "run_moss"
      get "sudo"
      match "upload_roster", via: [:get, :post]
      post "add_users_from_emails"
      get "user_lookup"
      get "users"
    end
  end

  resource :github_integration, only: [] do
    get "get_repositories"
    get "get_branches"
    get "get_commits"
  end
end
