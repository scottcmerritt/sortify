require "active_support/concern"

module Sortify
  module Relation
    extend ActiveSupport::Concern

    included do
      attr_accessor :sortify_values
    end

    def calculate(*args, &block)
      default_value = [:count, :sum].include?(args[0]) ? 0 : nil
      Sortify.process_result(self, super, default_value: default_value)
    end
  end
end