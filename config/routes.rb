Autolab3::Application.routes.draw do
  root 'courses#index'

  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }, path_prefix: 'auth'
  
  namespace :home do
    match 'developer_login', via: [ :post, :get ]
    get 'error'
    get 'no_user'
  end
  
  resources :users do
    get 'admin'
  end

  resources :courses do
    match 'report_bug', via: [ :post, :get ]
    get 'userLookup'

    resources :schedulers
    resources :jobs, only: :index do
      get 'getjob', on: :member
    end
    resources :announcements, except: :show
    resources :assessment_categories, except: :show
    resources :attachments

    resources :assessments, except: :update do
      resources :attachments
      resources :problems, except: [:index, :show] do
        get 'destroyConfirm', on: :member
      end
      resources :assessment_user_data, only: [:show, :edit, :update]
      resources :extensions, only: [:index, :create, :destroy]
      resources :submissions do
        resources :annotations, only: [:create, :update, :destroy]
        resources :scores, only: [:create, :show, :update]
        member do
          get 'destroyConfirm'
          get 'download'
          get 'listArchive', as: :list_archive
          get 'regrade'
          get 'view'
	        post 'autograde_done'
        end
        collection do
          get 'regradeAll'
          get 'downloadAll'
          get 'missing'
        end
      end

      member do
        match 'adminAutograde', via: [:get, :post]
      	match 'adminScoreboard', via: [:get, :post]
      	get 'adminPartners'
        get 'bulkExport'
        get 'bulkGrade'
      	get 'downloadSubmissions'
      	get 'releaseAllGrades'
      	get 'releaseSectionGrades'
      	get 'viewFeedback'
      	get 'reload'
      	get 'statistics'
      	get 'withdrawAllGrades'
      	get 'export'
      	get 'attachments'	
      	get 'extensions'
      	get 'submissions'
      	patch 'edit_*active_tab', action: :update
        get 'edit_*active_tab', action: :edit
        match 'handin', via: [:get, :post]
        get 'history'
        get 'viewFeedback'
        get 'viewGradesheet'
        get 'writeup'
        get 'handout'
        get 'partner'
        get 'scoreboard'
        get 'submission_popover'
        #partner actions
        match 'setPartner', via: [:get, :post]
        get 'importPartners'
        get 'deletePartner'
        get 'cancelRequest'
	      # gradesheet ajax actions
        post 'quickSetScore'
        post 'quickSetScoreDetails'
        post 'quickGetTotal'
        get 'score_grader_info'
        post 'submission_popover'
        # remote calls
        post 'official_submit'
        get  'unofficial_submit'
      end

      collection do
        match 'installAssessment', via: [:get, :post]
        match 'importAssessment', via: [:get, :post]
        match 'importAsmtFromTar', via: [:post]
        match 'getCategory', via: [:get, :post]
      end
    end

    resources :course_user_data do
      match 'sudo', via: [:get, :post]
      get 'unsudo'
      get 'destroyConfirm'

      resource :gradebook, only: :show do
        get 'bulkRelease'
        get 'csv'
        get 'invalidate'
        get 'statistics'
        get 'student'
        get 'view'
      end
    end
    
    resource :admin, only: :show do
      collection do
        get 'throwException'
      end
      get  'bulkRelease'
      get  'downloadRoster'
      match 'email', via: [:get, :post]
      get  'moss'
      post 'uploadRoster'
      get  'uploadRoster'
      get  'users'
      get  'reload'
      get  'sudo'
      post 'runMoss'
    end

  end
end
