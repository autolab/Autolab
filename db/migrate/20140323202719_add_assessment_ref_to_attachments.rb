# frozen_string_literal: true

class AddAssessmentRefToAttachments < ActiveRecord::Migration[4.2]
  def change
    add_reference :attachments, :assessment, index: true

    reversible do |dir|
      dir.up do
        Attachment.all.find_each do |a|
          a.assessment_id = (a.foreign_key if a.type == "AssessmentAttachment")
          a.save!
        end
      end
      dir.down do
      end
    end

    rename_column :attachments, :type, :type_old
    rename_column :attachments, :foreign_key, :foreign_key_old
  end
end
