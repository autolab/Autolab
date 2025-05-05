module AnnotationsHelper
  # Group annotations by rubric item
  def group_annotations_by_rubric_item(problem_annotations)
    problem_annotations.group_by(&:rubric_item_id)
  end
  
  # Separate global annotations from file-specific ones
  def separate_global_and_file_annotations(annotations)
    global_annotations = annotations.select(&:global_comment)
    file_annotations = annotations.reject(&:global_comment)
    [global_annotations, file_annotations]
  end
  
  # Group annotations by filename
  def group_annotations_by_filename(annotations)
    annotations.group_by { |a| a.filename || "" }
  end
  
  # Get all annotations for a problem
  def get_problem_annotations(problem_id, global_annotations_data, annotations_by_file_data)
    problem_annotations = []
    
    # Add global annotations for this problem
    if global_annotations_data.present?
      global_annotations_data.each do |annotation_data|
        id = annotation_data[4]
        annotation = Annotation.find_by(id: id)
        problem_annotations << annotation if annotation && annotation.problem_id == problem_id
      end
    end
    
    # Add file-specific annotations for this problem
    annotations_by_file_data.each do |_, file_annotations|
      file_annotations.each do |annotation_data|
        id = annotation_data[4]
        annotation = Annotation.find_by(id: id)
        problem_annotations << annotation if annotation && annotation.problem_id == problem_id
      end
    end
    
    problem_annotations.compact
  end
  
  # Get rubric items with their annotations
  def get_rubric_items_with_annotations(problem, submission, global_annotations_data, annotations_by_file_data)
    problem_annotations = get_problem_annotations(problem.id, global_annotations_data, annotations_by_file_data)
    annotations_by_rubric_item = group_annotations_by_rubric_item(problem_annotations)
    
    problem.rubric_items.map do |item|
      assignment = RubricItemAssignment.find_or_initialize_by(
        rubric_item_id: item.id,
        submission_id: submission.id
      )
      
      rubric_annotations = annotations_by_rubric_item[item.id] || []
      global_annotations, file_annotations = separate_global_and_file_annotations(rubric_annotations)
      annotations_by_filename = group_annotations_by_filename(file_annotations)
      
      {
        rubric_item: item,
        assignment: assignment,
        global_annotations: global_annotations,
        annotations_by_filename: annotations_by_filename
      }
    end
  end
  
  # Get non-rubric annotations for a problem
  def get_non_rubric_annotations(problem_id, global_annotations_data, annotations_by_file_data)
    # Process global annotations
    filtered_global_annotations = []
    global_annotations_data.each do |description, value, line, user, id, position, filename, shared, global|
      annotation = Annotation.find_by(id: id)
      if annotation && annotation.problem_id == problem_id && annotation.rubric_item_id.nil?
        filtered_global_annotations << [description, value, line, user, id, position, filename, shared, global]
      end
    end
    
    # Process file annotations
    filtered_annotations_by_file = {}
    annotations_by_file_data.each do |filename, annotations|
      file_annotations = []
      annotations.each do |description, value, line, user, id, position, filename, global|
        annotation = Annotation.find_by(id: id)
        if annotation && annotation.problem_id == problem_id && annotation.rubric_item_id.nil?
          file_annotations << [description, value, line, user, id, position, filename, global]
        end
      end
      filtered_annotations_by_file[filename] = file_annotations unless file_annotations.empty?
    end
    
    [filtered_global_annotations, filtered_annotations_by_file]
  end
  
  # Clean filename for display (extract basename)
  def clean_filename(filename)
    File.basename(filename.to_s)
  end
end
