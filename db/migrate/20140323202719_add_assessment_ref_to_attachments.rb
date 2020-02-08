class AddAssessmentRefToAttachments < ActiveRecord::Migration[4.2]
  def change
    add_reference :attachments, :assessment, index: true

    reversible do |dir|
      dir.up {
        Attachment.all.find_each do |a|
          if a.type == "AssessmentAttachment" then
            a.assessment_id = a.foreign_key
          else
            a.assessment_id = nil
          end
          a.save!
        end
      }
      dir.down {

      }
    end

    rename_column :attachments, :type, :type_old
    rename_column :attachments, :foreign_key, :foreign_key_old
  end
end
