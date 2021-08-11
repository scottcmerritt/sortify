module Sortify
    class RelationBuilder
      attr_reader :query_name, :column, :recency_key, :label #, :period
      #, :period, :day_start, :week_start, :n_seconds
      
      #def initialize(relation, column:, period:, time_zone:, time_range:, week_start:, day_start:, n_seconds:)
      def initialize(relation, column:, query_name:, recency_key:, label: nil, sort_order: "DESC", recent: true)
        @relation = relation
        @column = resolve_column(relation, column) unless column.nil?
        @query_name = query_name
        @table_name = resolve_table(relation) #"items"
        @class_name = resolve_class(relation)
        
        @recent = recent == false ? recent : true
        @lambda_key = recency_key #2
        @sort_order = sort_order

        @label = label #label.nil? ? Sortify::LABELS[0].to_s : label

        #if relation.default_timezone == :local
        #  raise Sortify::Error, "ActiveRecord::Base.default_timezone must be :utc to use Groupdate"
        #end
      end
  
      def generate
        #@relation.group(group_clause).where(*where_clause)

        case query_name
        when "nojoin"
            @relation.select(net_score_col).select(time_decay_col).where(*where_clause).order(order_clause)
        else
            @relation.select(net_score_col).select(time_decay_col).joins(join_clause).where(*where_clause).order(order_clause)
        end
      end
  
      private
        def default_sort_col
            "created_at"
        end
        def sort_order
            ["asc","desc"].include?(@sort_order.downcase) ? @sort_order : "desc"
        end
        
        def net_score_col
            "#{net_score} as net_score"
        end
        def net_score
            case query_name
            when "nofeedback","nojoin"
                time_decay
            else
                sort_col
            end
        end

        def time_decay_col
            "#{time_decay} as time_decay" 
        end
        
        def time_decay
            @recent ? Sortify::SortFields.time_decay_adjusted(@table_name,@lambda_key) : 1
        end

        def quality_min
            0
        end
        def interesting_min
            0
        end
        def learned_min
            0
        end
        def quality_col
            "cached_weighted_quality_score"
        end
        def interesting_col
            "cached_weighted_interesting_score"
        end
        def learned_col
            "cached_weighted_learnedfrom_score"
        end
        def votes_col
            "cached_votes_total"
        end
        def blended_col

            #"(#{quality_col} + #{interesting_col})"
            cols = []
            Sortify.blended_columns.each do |col|
                cols.push send(col+"_col")
            end
            "(#{cols.join(" + ")})"
        end
        def labeled_col
            "(cached_weighted_#{@label}_average * cached_weighted_#{@label}_total)"
        end

        def blended_where vote_filter_col
            cols = []
            Sortify.blended_columns.each do |col|
                cols.push(send(col+"_col") + " > " + send(col+"_min").to_s)
            end

            #["#{vote_filter_col} = ? AND #{quality_col} > ? AND #{interesting_col} > ?",@class_name, quality_min, interesting_min]
            ["#{vote_filter_col} = ? AND #{cols.join(" AND ")}",@class_name]
        end

        def labeled_where vote_filter_col
            ["#{vote_filter_col} = ?",@class_name]
        end

        def data_table
            Sortify.data_table
        end
  
        def sort_col
            case query_name
            when "quality", "interesting","learned","blended","labeled"
                "(#{time_decay}*#{send(query_name+"_col")})"
            when "blended_recent"
                "(#{time_decay}*#{blended_col})"
            when "nofeedback","nojoin"
                default_sort_col
            else
                votes_col
            end
        end
        
        def order_clause
            sort_col + " " + sort_order
        end

        def join_clause
            #tbl_name = @relation.class.name.pluralize.downcase #.klass.pluralize.downcase
            "LEFT JOIN #{data_table} ON #{data_table}.resource_id = #{@table_name}.id"
        end

        def group_clause
            #time_zone = @time_zone.tzinfo.name
            #adapter_name = @relation.connection.adapter_name
            query = ["id = ?",1]
            clause = @relation.send(:sanitize_sql_array, query)
        end
    
        def where_clause
            vote_filter_col = "#{data_table}.resource_type"
            #base_query = ["vote_caches.resource_type = ?",@class_name]
            case query_name
            when "blended"
                query = blended_where vote_filter_col
            when "weighted"
                query = weighted_where vote_filter_col
            when "interesting"
                query = ["#{vote_filter_col} = ? AND #{interesting_col} > ?",@class_name, interesting_min]
            when "learned"
                query = ["#{vote_filter_col} = ? AND #{learned_col} > ?",@class_name, learned_min]
            when "quality"
                query = ["#{vote_filter_col} = ? AND #{quality_col} > ?",@class_name, quality_min]
            when "nofeedback"
                query = ["(#{vote_filter_col} = ? AND #{votes_col} = ?) OR #{data_table}.id is NULL",@class_name,0]
            when "nojoin"
                query = ["id > ?",0]
            else
                query = ["#{vote_filter_col} = ?",@class_name]
            end
            
            clause = @relation.send(:sanitize_sql_array, query)
        end
  
      # resolves eagerly
      # need to convert both where_clause (easy)
      # and group_clause (not easy) if want to avoid this
      def resolve_column(relation, column)
        node = relation.send(:relation).send(:arel_columns, [column]).first
        node = Arel::Nodes::SqlLiteral.new(node) if node.is_a?(String)
        relation.connection.visitor.accept(node, Arel::Collectors::SQLString.new).value
      end

      def resolve_table(relation)
        node = relation.send(:relation).table_name #relation.send(:relation).klass
        node
      end
      def resolve_class(relation)
        relation.send(:relation).klass
      end
    end
  end