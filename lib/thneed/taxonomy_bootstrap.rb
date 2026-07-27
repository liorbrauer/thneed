# typed: false

require "yaml"

module Thneed
  class TaxonomyBootstrap
    class Error < StandardError; end
    class ConflictError < Error; end
    class ConfigurationError < Error; end

    TAG_DEFAULTS = {
      "active" => true,
      "hotness_mod" => 0.0,
      "is_media" => false,
      "permit_by_new_users" => true,
      "privileged" => false,
      "quorum" => 2
    }.freeze
    TAG_ATTRIBUTES = (TAG_DEFAULTS.keys + ["description"]).freeze
    TAG_KEYS = (TAG_ATTRIBUTES + ["name"]).freeze

    def initialize(path:, moderator:, dry_run: false, io: $stdout)
      @path = Pathname(path)
      @moderator = moderator
      @dry_run = dry_run
      @io = io
    end

    def call
      categories = load_categories
      conflicts = find_conflicts(categories)
      raise ConflictError, conflicts.join("\n") if conflicts.any?

      changes = planned_changes(categories)
      print_plan(changes)
      return changes if @dry_run

      ApplicationRecord.transaction do
        categories.each do |category_config|
          category = Category.find_by(category: category_config.fetch("name"))
          category ||= Category.create!(
            category: category_config.fetch("name"),
            edit_user_id: @moderator.id
          )

          category_config.fetch("tags").each do |tag_config|
            next if Tag.find_by(tag: tag_config.fetch("name"))

            Tag.create!(
              desired_tag_attributes(tag_config).merge(
                tag: tag_config.fetch("name"),
                category: category,
                edit_user_id: @moderator.id
              )
            )
          end
        end
      end

      changes
    end

    private

    def load_categories
      document = YAML.safe_load_file(@path, aliases: false)
      categories = document.is_a?(Hash) ? document["categories"] : nil
      unless categories.is_a?(Array) && categories.any?
        raise ConfigurationError, "#{@path} must contain a non-empty categories list"
      end

      validate_configuration!(categories)
      categories
    rescue Psych::Exception => e
      raise ConfigurationError, "Could not read #{@path}: #{e.message}"
    end

    def validate_configuration!(categories)
      category_names = categories.pluck("name")
      duplicate_categories = category_names.tally.select { |_name, count| count > 1 }.keys
      if duplicate_categories.any?
        raise ConfigurationError, "Duplicate categories: #{duplicate_categories.join(", ")}"
      end

      tag_names = []
      categories.each do |category|
        unless category.is_a?(Hash) &&
            category.keys.sort == ["name", "tags"] &&
            category["tags"].is_a?(Array) &&
            category["tags"].any?
          raise ConfigurationError, "Each category must have only a name and a non-empty tags list"
        end

        category_record = Category.new(category: category["name"])
        category_errors = validation_errors_except_uniqueness(category_record)
        if category_errors.any?
          raise ConfigurationError,
            "Invalid category #{category["name"].inspect}: #{category_errors.to_sentence}"
        end

        category["tags"].each do |tag|
          unless tag.is_a?(Hash) && tag.keys.all? { |key| TAG_KEYS.include?(key) } &&
              tag.key?("name") && tag.key?("description")
            raise ConfigurationError, "Invalid configuration for a tag in #{category["name"]}"
          end

          tag_names << tag["name"]
          tag_record = Tag.new(
            desired_tag_attributes(tag).merge(tag: tag["name"], category: category_record)
          )
          tag_errors = validation_errors_except_uniqueness(tag_record)
          if tag_errors.any?
            raise ConfigurationError,
              "Invalid tag #{tag["name"].inspect}: #{tag_errors.to_sentence}"
          end
        end
      end

      duplicate_tags = tag_names.tally.select { |_name, count| count > 1 }.keys
      if duplicate_tags.any?
        raise ConfigurationError, "Duplicate tags: #{duplicate_tags.join(", ")}"
      end
    end

    def find_conflicts(categories)
      categories.flat_map do |category|
        category.fetch("tags").filter_map do |tag_config|
          existing = Tag.find_by(tag: tag_config.fetch("name"))
          next unless existing

          expected = desired_tag_attributes(tag_config).merge(
            "category" => category.fetch("name")
          )
          actual = existing.attributes.slice(*TAG_ATTRIBUTES).merge(
            "category" => existing.category.category
          )
          differences = expected.filter_map do |attribute, value|
            next if actual.fetch(attribute) == value

            "#{attribute}=#{actual.fetch(attribute).inspect} (expected #{value.inspect})"
          end
          next if differences.empty?

          "Tag #{existing.tag.inspect} conflicts: #{differences.join(", ")}"
        end
      end
    end

    def planned_changes(categories)
      {
        categories: categories.count { |category| !Category.exists?(category: category.fetch("name")) },
        tags: categories.sum do |category|
          category.fetch("tags").count { |tag| !Tag.exists?(tag: tag.fetch("name")) }
        end
      }
    end

    def print_plan(changes)
      verb = @dry_run ? "Would create" : "Creating"
      @io.puts "#{verb} #{changes.fetch(:categories)} categories and #{changes.fetch(:tags)} tags."
      @io.puts "No changes needed." if changes.values.all?(&:zero?)
    end

    def desired_tag_attributes(tag)
      TAG_DEFAULTS.merge(tag.slice(*TAG_ATTRIBUTES))
    end

    def validation_errors_except_uniqueness(record)
      record.valid?
      record.errors.filter_map do |error|
        error.full_message unless error.type == :taken
      end
    end
  end
end
