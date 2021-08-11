# dependencies
require "active_support/core_ext/module/attribute_accessors"
#require "active_support/time"

# modules
require "sortify/magic"
require "sortify/magic_new"
require "sortify/relation_builder"

require "sortify/version"


module Sortify
  class Error < StandardError; end
  # Your code goes here...

  # currently, :labeled requires a vote_scope/label as well, the other queries ignore vote_scope
  FIELDS = [:labeled,:blended,:quality,:interesting,:learned,:votes,:nofeedback,:nojoin] # [:second, :minute, :hour, :day, :week, :month, :quarter, :year, :day_of_week, :hour_of_day, :minute_of_hour, :day_of_month, :day_of_year, :month_of_year]
  
  LABELS = [:quality,:interesting,:fun,:funny,:learnedfrom,:spam,:ad,:clickbait,:english]

  METHODS = FIELDS.map { |v| :"sortify_by_#{v}" } + [:sortify_by_field]
  LAMBDA_VALUES = [-0.02445,-0.0489,-0.0990, nil]

  mattr_accessor :data_table, :blended_columns
  self.blended_columns = ["quality","interesting"]
  self.data_table = "vote_caches"

  class SortFields
    def initialize

    end
    def self.time_decay table_name, time_column = "created_at"
      "EXTRACT(EPOCH FROM (NOW()::timestamp - #{table_name}.#{time_column}::timestamp))/(24*60*60)"
    end
    
    def self.time_decay_adjusted table_name, lambda_key
      lambda_val = Sortify::LAMBDA_VALUES[lambda_key]
      time_decay_query = Sortify::SortFields.time_decay(table_name)
      lambda_val.nil? ? "1" : "exp(#{time_decay_query}*#{lambda_val})"
    end
  end

  # api for gems like ActiveMedian or Kaminari
  def self.process_result(relation, result, **options)
    if relation.sortify_values
      result = Sortify::Magic::Relation.process_result(relation, result, **options)
    end
    result
  end

end

require "sortify/enumerable"

ActiveSupport.on_load(:active_record) do
  require "sortify/active_record"
end