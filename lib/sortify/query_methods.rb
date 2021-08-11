module Sortify
    module QueryMethods

        Sortify::FIELDS.each do |query_name|
            define_method :"sortify_by_#{query_name}" do |**options|
            Sortify::MagicNew::Relation.generate_relation(self,
            query_name: query_name.to_s,
            **options
            )
            end

        end

      def sortify(query_name, **options)
        send("sortify_by_#{query_name}", **options)
      end
      
      def sortify_by_field(query_name, permit: nil, **options)
        #Sortify::Magic.validate_query(query_name, permit)
        send("sortify_by_#{query_name}", **options)
      end
  
    end
  end