module CourseTransfer
  # Describes files owned by one exported record.
  FileMapping = Struct.new(
    :record, :name, :type, :path, :root, :base, :exclude, :attachment,
    keyword_init: true
  ) do
    # @return [CourseTransfer::FileMapping]
    def self.file(record, name, path, root:, within:)
      new(record:, name:, type: :file, path:, root:, base: within)
    end

    # @return [CourseTransfer::FileMapping]
    def self.tree(record, path, within:, exclude: [])
      new(record:, name: "tree", type: :tree, path:, root: path, base: within, exclude:)
    end

    # @return [CourseTransfer::FileMapping]
    def self.active_storage(record, attachment, fallback:, within:)
      new(
        record:,
        name: "attachment",
        type: :active_storage,
        path: fallback,
        root: within,
        attachment:
      )
    end
  end
end
