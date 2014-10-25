class AssessmentCategoriesController < ApplicationController

  action_auth_level :index, :instructor
  def index
    @categories = @course.assessment_categories
  end

  action_auth_level :new, :instructor
  def new
    # nada
  end

  action_auth_level :create, :instructor
  def create
    @category = @course.assessment_categories.new(new_category_params)
    if @category.save
      redirect_to course_assessment_categories_path(@course) and return 
    else
      flash[:error] = "Create new assessment category failed. Check all fields"
      redirect_to action: :new and return
    end
  end

  action_auth_level :edit, :instructor
  def edit
    @category = @course.assessment_categories.find(params[:id])
    
    if @category.nil?
      flash[:error] = "Can't find category in the course."
      redirect_to course_assessment_categories_path(@course) and return
    end
  end
    
  action_auth_level :update, :instructor
  def update
    @category = @course.assessment_categories.find(params[:id])
    
    if @category.nil?
      flash[:error] = "Can't find category in the course."
      redirect_to course_assessment_categories_path(@course) and return
    end
    
    if @category.update(category_params)
      flash[:success] = "Successful updated category name to #{@category.name}."
      redirect_to course_assessment_categories_path(@course) and return
    else
      flash[:error] = "Failed to update category. Check all fields"
      redirect_to :new and return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @category = @course.assessment_categories.find(params[:id])
    assessments = @category.assessments.where("visible_at < ?", Time.now())
    if assessments.size > 0 then
      flash[:error] = "Could not delete category " +
              @category.name + " since " +
              assessments.size.to_s + " assessments still " +
              "exist within it. Please move or delete " +
              "these assessments first."
      redirect_to action: :index and return
    end
    @category.destroy()
    redirect_to action: :index and return
  end
  
private

  def new_category_params
    params.require(:assessment_category).permit(:name)
  end
  
  def category_params
    params.require(:assessment_category).permit(:name)
  end

end
