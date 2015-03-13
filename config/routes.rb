Autolab3::Application.routes.draw do
  root 'courses#index'

  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }, path_prefix: 'auth'

  get 'contact', to: 'home#contact'

  namespace :home do
    match 'developer_login', via: [ :post, :get ]
    get 'error'
    get 'no_user'
    get 'vmlist'
  end

  resource :admin do
    match 'emailInstructors', via: [:get, :post]
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
    resources :attachments

    resources :assessments, except: :update do
      resources :assessment_user_data, only: [:edit, :update]
      resources :attachments
      resources :extensions, only: [:index, :create, :destroy]
      resources :groups, except: :edit do
        member do
          post 'add'
          post 'join'
          post 'leave'
        end
        post 'import', on: :collection
      end
      resources :problems, except: [:index, :show]
      resources :submissions do
        resources :annotations, only: [:create, :update, :destroy]
        resources :scores, only: [:create, :show, :update]
        member do
          get 'destroyConfirm'
          get 'download'
          get 'listArchive', as: :list_archive
          get 'view'
        end
        collection do
          get 'downloadAll'
          get 'missing'
        end
      end

      member do
        match 'adminAutograde', via: [:get, :post]
        match 'adminScoreboard', via: [:get, :post]
        match 'bulkGrade', via: [:get, :post]
        post 'bulkGrade_complete'
        get 'bulkExport'
        get 'releaseAllGrades'
        get 'releaseSectionGrades'
        get 'viewFeedback'
        get 'reload'
        get 'statistics'
        get 'withdrawAllGrades'
        get 'export'
        patch 'edit/*active_tab', action: :update
        get 'edit/*active_tab', action: :edit
        post 'handin'
        get 'takeQuiz'
        post 'submitQuiz'
        get 'history'
        get 'viewGradesheet'
        get 'writeup'
        get 'handout'
        get 'scoreboard'

        # autograde actions
        post 'autograde_done'
        post 'regrade'
        post 'regradeBatch'
        post 'regradeAll'

        # SVN actions
        get 'adminSVN'
        post 'importSVN'
        post 'setRepository'

        # gradesheet ajax actions
        post 'quickSetScore'
        post 'quickSetScoreDetails'
        get 'quickGetTotal'
        get 'score_grader_info'
        get 'submission_popover'

        # remote calls
        match 'local_submit', via: [:get, :post]
        get  'log_submit'
      end

      collection do
        get 'installAssessment'
        post 'importAssessment'
        post 'importAsmtFromTar'
        post 'installQuiz'
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

    get  'manage'
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
