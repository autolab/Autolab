class SplitAnnotations < ActiveRecord::Migration[4.2]
  def up
    require 'uri'
    Annotation.find_each do |annotation|
      text = annotation.text
      puts text
      if text.blank? then
        if annotation.destroy then # don't need no blank annotations cluttering up the db
          puts ">>>>>>>>>>>>>>>>>>>DELETED<<<<<<<<<<<<<<<<<<"
        end
        next
      end

      res = text.split("[")
      
      comment = text

      if res.size > 1 then
        len = res.size
        points = res[len-1]
        res.delete_at(len-1)

        comment = res.join("[")

        points = points.split(":") 
        if points.size == 1 then
          annotation.value = points[0].delete("]").to_f
        else
          problemStr =  points[1].delete("]")
          annotation.problem = annotation.submission.assessment.problems.find_by(name: problemStr)
          if points[0] == "?" then
            annotation.value = 0;
          else
            annotation.value = points[0].to_f
          end 
        end
      end

      annotation.comment = if comment.blank? then
        "-" # otherwise the validation will fail
      elsif comment.include? " " then # test for whether this string has been encoded
        comment
      else
        URI.decode(comment)
      end

      if annotation.save == false then
        puts "-------------------NOT UPDATED----------------"
      end
    end
  end
end
