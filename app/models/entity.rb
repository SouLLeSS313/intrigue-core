module Intrigue
  module Model
    class Entity
      include DataMapper::Resource

      property :id,       Serial
      property :type,     Discriminator
      property :name,     String, :length => 500
      property :details,  Object, :default => {} #Text, :length => 100000

      belongs_to :project, :default => lambda { |r, p| Project.first }

      has n, :task_results, :through => Resource, :constraint => :destroy
      has n, :scan_results, :through => Resource, :constraint => :destroy

      #belongs_to :scan_result, :required => false

      #has n, :children, self, :through => :task_results, :via => :base_entity
      #validates_uniqueness_of :name

      def self.all_in_current_project
        all(:project_id => 1)
      end

      def allowed_tasks
        ### XXX - this needs to be limited to tasks that accept this type
        TaskFactory.allowed_tasks_for_entity_type(type_string)
      end

      def to_s
        "#{type_string}: #{@name}"
      end

      def type_string
        attribute_get(:type).to_s.gsub(/^.*::/, '')
      end

      # Method returns true if entity has the same attributes
      # false otherwise
      def match?(entity)
        if ( entity.name == @name && entity.type == @type )
            return true
        end
      false
      end

      def form
         %{<div class="form-group">
          <label for="entity_type" class="col-xs-4 control-label">Entity Type</label>
          <div class="col-xs-6">
            <select class="form-control input-sm" id="entity_type" name="entity_type">
              <option> #{self.type_string} </option>
            </select>
          </div>
        </div>
        <div class="form-group">
          <label for="attrib_name" class="col-xs-4 control-label">Entity Name</label>
          <div class="col-xs-6">
            <input type="text" class="form-control input-sm" id="attrib_name" name="attrib_name" value="#{self.name}">
          </div>
        </div>}
      end

      def self.descendants
        ObjectSpace.each_object(Class).select { |klass| klass < self }
      end

      ###
      ### Export!
      ###
      def export_hash
        {
          :type => @type,
          :name => @name,
          :details => @details
        }
      end

      def export_json
        export_hash.to_json
      end

      def export_csv
        export_string = "#{@id},#{@type},#{@name},"
        @details.each{|k,v| export_string << "#{k}=#{v};".gsub(",","#") }
        export_string << ","
      export_string
      end

      def export_tsv
        export_string = "#{@id}\t#{@type}\t#{@name}\t"
        @details.each{|k,v| export_string << "#{k}##{v};" }
      export_string
      end

      private
      def _escape_html(text)
        Rack::Utils.escape_html(text)
        text
      end
    end
  end
end
