# frozen_string_literal: true

require "fileutils"
require "pathname"
require "yaml"

module CourseTransfer
  class Exporter
    # @param values [ActiveRecord::Relation]
    # @return [Array<(Symbol, ActiveRecord::Relation)>]
    def dependencies(values)
      raise NotImplementedError
    end


    # @return [Array<(Symbol, Symbol)>]
    def included_fields
      raise NotImplementedError
    end

    # @param record [ApplicationRecord]
    def natural_id(record)
      raise NotImplementedError
    end

    # @return [Boolean]
    def inline?
      true
    end

    # @param record [ApplicationRecord]
    def other_export(record) end

    # @param record [ApplicationRecord]
    def other_import(record) end
  end

  class ExportManager
    def initialize
      # @type [Hash{Symbol=>Exporter}]
      @exporter_map = {}
      # @type [Hash{Symbol=>ActiveRecord::Relation}]
      @relation_map = {}

      # @type [Array<Symbol>]
      @export_search_order = []
    end

    # @param name [Symbol]
    # @param exporter [Exporter]
    # @param base_relation [ActiveRecord::Relation]
    def register_exporter(name, exporter, base_relation)
      @exporter_map[name] = exporter
      @relation_map[name] = base_relation
      @export_search_order << name
    end

    # @param values [Array<(Symbol, ActiveRecord::Relation)>]
    def export(values)
      # load values planned to be exported
      to_be_exported = {}
      @relation_map.each do |name, relation|
        to_be_exported[name] = relation
      end
      values.each do |name, relation|
        to_be_exported[name] = to_be_exported[name].or(relation)
      end

      # go through dependency order, searching for records to export via dependency
      @export_search_order.each do |name|
        next_exports = @exporter_map[name].dependencies(to_be_exported[name])
        next_exports.each do |sub_name, sub_relation|
          to_be_exported[sub_name] = to_be_exported[sub_name].or(sub_relation)
        end
      end

      @export_search_order.each do |name|

      end
    end

    # @param file [File]
    # @param relation [ActiveRecord::Relation]
    private def export_relation(file, relation, fields, included_fields)
      relation.in_batches(of: 1000) do |batch|
        batch.pluck(*fields).each do |values|
          row = fields.zip(values).to_h
          file.write(row.to_yaml)
        end
      end
    end
  end
end
