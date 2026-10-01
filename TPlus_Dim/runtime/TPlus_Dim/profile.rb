# encoding: UTF-8
module TPlus
  module Dim
    module Profile
      extend self
      DICTIONARY = 'TPlus_Dim'.freeze unless const_defined?(:DICTIONARY, false)

      def read(model)
        raw = model.get_attribute(DICTIONARY, 'profile_json', nil)
        return nil unless raw.is_a?(String)
        data = JSON.parse(raw)
        return nil unless data.is_a?(Hash)
        Engine.validate(Dim::DEFAULTS.merge(data))
      rescue StandardError => error
        puts "[T+ Dim profile] #{error.message}"
        nil
      end

      def write(model, config)
        model.set_attribute(DICTIONARY, 'profile_json', JSON.generate(config))
        model.set_attribute(DICTIONARY, 'schema', 2)
      end
    end

    # Only newly-added native Dim/Text are queued. Existing model entities are never
    # restyled merely by loading a model or attaching an observer.
    class ProfileService
      class EntitiesWatch < Sketchup::EntitiesObserver
        def initialize(service); @service = service; end
        def onElementAdded(entities, entity); @service.added(entities, entity); end
      end
      class DefinitionsWatch < Sketchup::DefinitionsObserver
        def initialize(service); @service = service; end
        def onComponentAdded(_definitions, definition); @service.watch_collection(definition.entities); end
      end
      class ModelWatch < Sketchup::ModelObserver
        def initialize(service); @service = service; end
        def onTransactionCommit(_model); @service.committed; end
        def onTransactionUndo(_model); @service.history_changed; end
        def onTransactionRedo(_model); @service.history_changed; end
        def onDeleteModel(_model); @service.dispose; end
      end
      class AppWatch < Sketchup::AppObserver
        def expectsStartupModelNotifications; true; end
        def onNewModel(model); ProfileService.for_model(model); end
        def onOpenModel(model); ProfileService.for_model(model); end
        def onActivateModel(model); ProfileService.for_model(model); end
      end

      def self.install
        unless @app_watch
          @app_watch = AppWatch.new
          Sketchup.add_observer(@app_watch)
        end
        for_model(Sketchup.active_model)
      end

      def self.for_model(model)
        @services ||= {}
        @services[model] ||= new(model)
      end

      def self.shutdown
        (@services || {}).each_value(&:dispose)
        @services = {}
        Sketchup.remove_observer(@app_watch) if @app_watch
        @app_watch = nil
      end

      def initialize(model)
        @model = model
        @collections = {}
        @pending = {}
        @entities_watch = EntitiesWatch.new(self)
        @definitions_watch = DefinitionsWatch.new(self)
        @model_watch = ModelWatch.new(self)
        @model.add_observer(@model_watch)
        reconfigure
      end

      def reconfigure
        @config = Profile.read(@model)
        if @config && @config['auto_new']
          watch_collection(@model.entities)
          @model.definitions.each { |definition| watch_collection(definition.entities) }
          unless @definitions_attached
            @model.definitions.add_observer(@definitions_watch)
            @definitions_attached = true
          end
        else
          @collections.each_key { |entities| entities.remove_observer(@entities_watch) }
          @collections.clear
          @model.definitions.remove_observer(@definitions_watch) if @definitions_attached
          @definitions_attached = false
        end
      end

      def watch_collection(entities)
        return unless @config && @config['auto_new']
        return if @collections.key?(entities)
        entities.add_observer(@entities_watch)
        @collections[entities] = true
      end

      def with_paused
        previous = @paused
        @paused = true
        yield
      ensure
        @paused = previous
        reconfigure unless @paused
      end

      def added(entities, entity)
        return if @paused || !@config || !@config['auto_new'] || !entity.valid?
        return if CustomDim.source?(entity) || CustomDim.view?(entity)
        return unless Engine.target?(entity, @config)
        @pending[entity.persistent_id] = [entities, entity]
      end

      def committed
        return if @paused
        @config = Profile.read(@model)
        return if @timer
        @timer = UI.start_timer(0.0, false) { @timer = nil; flush }
      end

      def history_changed
        @pending.clear
        UI.stop_timer(@timer) if @timer
        @timer = UI.start_timer(0.0, false) { @timer = nil; reconfigure }
      end

      def flush
        batch = @pending.values
        @pending.clear
        @config = Profile.read(@model)
        batch = [] unless @config && @config['auto_new']
        updates = CustomDim.updates(@model)
        return if batch.empty? && updates.empty?
        with_paused do
          # Appearance applies to new objects. Placement and content stay under
          # the manual drawing tool's control, preserving its chosen offset/text.
          config = (@config || Dim::DEFAULTS).merge('change_offset' => false, 'reset_text' => false)
          stats = {dimensions: 0, texts: 0, fonts: 0, fonts_skipped: 0, offset_skipped: 0}
          @model.start_operation('T+ Dim · Quy chuẩn đối tượng mới', true, false, true)
          begin
            materials = {}
            materials[:dim] = Engine.color_material(@model, config['dim_color'], 'DIM') if config['change_color'] && batch.any? { |_, e| e.valid? && e.is_a?(Sketchup::Dimension) }
            materials[:text] = Engine.color_material(@model, config['text_color'], 'TEXT') if batch.any? { |_, e| e.valid? && e.is_a?(Sketchup::Text) }
            if config['assign_tags']
              stats[:dim_tag] = @model.layers['T+_DIM'] || @model.layers.add('T+_DIM')
              stats[:text_tag] = @model.layers['T+_TEXT'] || @model.layers.add('T+_TEXT')
            end
            batch.each do |entities, entity|
              next unless entity.valid?
              begin
                if entity.is_a?(Sketchup::Dimension)
                  Engine.apply_dimension(entity, config, materials[:dim], @model.edit_transform, stats)
                elsif entity.is_a?(Sketchup::Text)
                  Engine.apply_text(entity, config, materials[:text], stats)
                end
              rescue StandardError => error
                puts "[T+ Dim auto] Giữ đối tượng native #{entity.persistent_id}: #{error.message}"
                Dim.report("Không chuyển được một Dim/Text mới: #{error.message}", true) if Dim.respond_to?(:report)
              end
            end
            CustomDim.refresh(@model, updates)
          ensure
            # Never abort a transparent operation: that could roll back the user's
            # preceding draw operation. Commit the changes recorded so far.
            @model.commit_operation
          end
        end
      rescue StandardError => error
        puts "[T+ Dim auto] #{error.message}\n#{error.backtrace.join("\n")}"
      end

      def dispose
        UI.stop_timer(@timer) if @timer
        @collections.each_key { |entities| entities.remove_observer(@entities_watch) rescue nil }
        @model.definitions.remove_observer(@definitions_watch) if @definitions_attached
        @model.remove_observer(@model_watch)
        @collections.clear
        @pending.clear
      rescue StandardError
        nil
      end
    end
  end
end
