# frozen_string_literal: true

class SplitAnnotations < ActiveRecord::Migration[4.2]
  def up
    require "uri"
    Annotation.find_each do |annotation|
      text = annotation.text
      puts text
      if text.blank?
        if annotation.destroy # don't need no blank annotations cluttering up the db
          puts ">>>>>>>>>>>>>>>>>>>DELETED<<<<<<<<<<<<<<<<<<"
        end
        next
      end

      res = text.split("[")

      comment = text

      if res.size > 1
        len = res.size
        points = res[len - 1]
        res.delete_at(len - 1)

        comment = res.join("[")

        points = points.split(":")
        if points.size == 1
          annotation.value = points[0].delete("]").to_f
        else
          problemStr = points[1].delete("]")
          annotation.problem = annotation.submission.assessment.problems.find_by(name: problemStr)
          annotation.value = if points[0] == "?"
                               0
                             else
                               points[0].to_f
                             end
        end
      end

      annotation.comment = if comment.blank?
                             "-" # otherwise the validation will fail
                           elsif comment.include? " " # test for whether this string has been encoded
                             comment
                           else
                             URI.decode(comment)
                           end

      puts "-------------------NOT UPDATED----------------" if annotation.save == false
    end
  end
end
