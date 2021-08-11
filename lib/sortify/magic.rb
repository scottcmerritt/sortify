require "i18n"

module Sortify
  class Magic
    attr_accessor :query_name, :options

    def initialize(query_name:, **options)
        @query_name = query_name
        @options = options
    end

    def self.validate_period(period, permit)
      permitted_periods = ((permit || Sortify::FIELDS).map(&:to_sym) & Sortify::FIELDS).map(&:to_s)
      raise ArgumentError, "Unpermitted period" unless permitted_periods.include?(period.to_s)
    end

    class Enumerable < Magic
      def sort_by(enum, &_block)
        group = enum.group_by do |v|
          v = yield(v)
          raise ArgumentError, "Not a time" unless v.respond_to?(:to_time)
          series_builder.round_time(v)
        end
        series_builder.generate(group, default_value: [], series_default: false)
      end

      def self.sort_by(enum, query_name, options, &block)
        Sortify::Magic::Enumerable.new(query_name: query_name, **options).group_by(enum, &block)
      end
    end

    class Relation < Magic
      def initialize(**options)
        super(**options.reject { |k, _| [:default_value, :carry_forward, :last, :current].include?(k) })
        @options = options
      end

      def self.generate_relation(relation, field:, **options)
        magic = Sortify::Magic::Relation.new(**options)

        # generate ActiveRecord relation
        relation =
        RelationBuilder.new(
            relation,
            column: field,
            query_name: magic.query_name
          ).generate

        # add Groupdate info
        #magic.group_index = relation.group_values.size - 1
        #(relation.groupdate_values ||= []) << magic

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