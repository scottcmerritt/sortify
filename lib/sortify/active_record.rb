require "active_record"
require "sortify/query_methods"
require "sortify/relation"

ActiveRecord::Base.extend(Sortify::QueryMethods)
ActiveRecord::Relation.include(Sortify::Relation)