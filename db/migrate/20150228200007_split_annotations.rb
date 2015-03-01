class SplitAnnotations < ActiveRecord::Migration
  def change

    Annotation.find_each do |annotation|
        text = annotation.text


        res = text.split("[");
        
        if res.size == 1 then
            annotation.comment = text
        end

        if res.size > 1 then

            len = res.size
            points = res[len-1]
            res.delete_at(len-1)

            points = points.split(":");
            comment = res.join("[");
            annotation.comment = comment
           
            if points.size == 1 then
              annotation.value = points[0].delete("]").to_f
            else
              if points[0] == "?" then
                annotation.problem = points[1].delete("]").to_i
                annotation.value = 0;
              else
                problemStr =  points[1].delete("]")
                problem = annotation.submission.assessment.problems.find_by(name: problemStr)
                annotation.problem = problem
                annotation.value =  points[0].to_f
              end 
            end
        end

        annotation.save!
    end

  end
end
