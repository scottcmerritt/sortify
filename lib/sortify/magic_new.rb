require "i18n"

module Sortify
  class MagicNew
    attr_accessor :query_name, :label, :sort_order, :recency_key, :recent, :options

    def initialize(query_name:, **options)
        @query_name = query_name
        @options = options

        @recent = options[:recent] == false ? false : true
        @recency_key = options[:recency_key] ? options[:recency_key].to_i : 2
        @label = options[:label] ? options[:label] : nil
        @label = @label.nil? ? Sortify::LABELS[0].to_s : @label

        @sort_order = options[:sort_order] ? (["asc","desc"].include?(options[:sort_order].downcase) ? options[:sort_order] : "desc") : "desc"
        
    end

    def self.validate_period(period, permit)
      permitted_periods = ((permit || Sortify::FIELDS).map(&:to_sym) & Sortify::FIELDS).map(&:to_s)
      raise ArgumentError, "Unpermitted period" unless permitted_periods.include?(period.to_s)
    end

    class Enumerable < MagicNew
      def sortify_by(enum, &_block)
        group = enum.group_by do |v|
          v = yield(v)
          raise ArgumentError, "Not a time" unless v.respond_to?(:to_time)
          series_builder.round_time(v)
        end
        series_builder.generate(group, default_value: [], series_default: false)
      end

      def self.sortify_by(enum, query_name, options, &block)
        Sortify::MagicNew::Enumerable.new(query_name: query_name, **options).group_by(enum, &block)
      end
    end

    class Relation < MagicNew
      def initialize(**options)
        super(**options.reject { |k, _| [:default_value, :carry_forward, :last, :current].include?(k) })
        @options = options
      end

      def self.generate_relation(relation, field: nil, **options)
        magic = Sortify::MagicNew::Relation.new(**options)

        # generate ActiveRecord relation
        relation =
          RelationBuilder.new(
            relation,
            column: field,
            query_name: magic.query_name,
            recent: magic.recent,
            recency_key: magic.recency_key,
            label: magic.label,
            sort_order: magic.sort_order
          ).generate

        relation

      end

      # allow any options to keep flexible for future
      def self.process_result(relation, result, **options)
        relation.sortify_values.reverse.each do |gv|
          result = gv.perform(relation, result, default_value: options[:default_value])
        end
        result
      end
    end
  end
end