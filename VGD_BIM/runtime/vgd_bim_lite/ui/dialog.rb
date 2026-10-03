require 'json'
module VGD
  module BIM
    module UI
      class SelectionObserver < Sketchup::SelectionObserver
        def initialize(panel); @panel = panel; end
        def onSelectionBulkChange(selection); @panel.selection_changed; end
        def onSelectionAdded(selection, entity); @panel.selection_changed; end
        def onSelectionRemoved(selection, entity); @panel.selection_changed; end
        def onSelectionCleared(selection); @panel.selection_changed; end
      end
      class Dialog
        def initialize(mode)
          @mode = mode
          @records = []
          @rows = []
          @targets = []
          @generation = 0
          @dialog = ::UI::HtmlDialog.new(dialog_title: 'VGD BIM Lite', preferences_key: "VGD_BIM_#{mode}", scrollable: true, resizable: true, width: 960, height: 720, style: ::UI::HtmlDialog::STYLE_DIALOG)
          @dialog.set_file(File.join(BIM::ROOT, 'html', 'index.html'))
          @dialog.add_action_callback('ready') { |_ctx| safely { refresh } }
          @dialog.add_action_callback('refresh') { |_ctx| safely { refresh } }
          @dialog.add_action_callback('open_panel') { |_ctx, mode| safely { BIM.open_panel(mode) if %w[information scan mapping validate_model rules].include?(mode) } }
          @dialog.add_action_callback('apply') { |_ctx, payload| safely { apply(JSON.parse(payload)) } }
          @dialog.add_action_callback('clear') { |_ctx| safely { clear } }
          @dialog.add_action_callback('select_entity') { |_ctx, index| safely { select_entity(index.to_i) } }
          @dialog.add_action_callback('preview_convert') { |_ctx, payload| safely { preview_convert(JSON.parse(payload)) } }
          @dialog.add_action_callback('confirm_convert') { |_ctx| safely { confirm_convert } }
          @dialog.add_action_callback('save_rules') { |_ctx, payload| safely { check_model!; MappingRules.save(JSON.parse(payload)); refresh } }
          @dialog.add_action_callback('export_rules') { |_ctx| safely { check_model!; path = ::UI.savepanel('Export VGD mapping rules', '', 'vgd_mapping_rules.json'); MappingRules.export_file(path) if path } }
          @dialog.add_action_callback('import_rules') { |_ctx| safely { check_model!; path = ::UI.openpanel('Import VGD mapping rules', '', 'JSON|*.json||'); if path; MappingRules.import_file(path); refresh; end } }
          @dialog.set_on_closed { @generation += 1; detach }
        end
        def show; @dialog.show; end
        def visible?; @dialog.visible?; end
        def safely
          yield
        rescue StandardError => error
          BIM.log(error.message)
          emit('message', {error: error.message})
        end
        def emit(event, payload)
          json = JSON.generate(payload).gsub('<', '\\u003c').gsub("\u2028", '\\u2028').gsub("\u2029", '\\u2029')
          @dialog.execute_script("window.VGD.receive(#{JSON.generate(event)}, #{json})")
        end
        def check_model!
          raise 'Model changed. Refresh before continuing.' unless @model == Sketchup.active_model
        end
        def detach
          @model.selection.remove_observer(@observer) if @model && @observer
          @observer = nil
        rescue StandardError
          @observer = nil
        end
        def selection_changed
          return unless @mode == 'information' || @mode == 'convert_selection'
          return unless @dialog.visible?
          ::UI.stop_timer(@selection_timer) if @selection_timer
          @selection_timer = ::UI.start_timer(0.05, false) { safely { refresh if @dialog.visible? } }
        end
        def refresh
          @generation += 1
          @pending = nil
          detach
          @model = Sketchup.active_model
          emit('config', {mode: @mode, version: BIM::VERSION, fields: Schema::FIELDS, categories: Schema::CATEGORIES, units: Schema::UNITS, methods: Schema::METHODS, presets: BIM.presets})
          case @mode
          when 'information', 'convert_selection'
            @observer = SelectionObserver.new(self)
            @model.selection.add_observer(@observer)
            @targets = @model.selection.to_a.select { |e| Data.supported?(e) && e.valid? }
            ancestor_locked = (@model.active_path || []).any? { |e| e.locked? }
            @records = @targets.map { |e| {entity: e, path: (@model.active_path || []) + [e], transform: @model.edit_transform * e.transformation, locked: ancestor_locked || e.locked?} }
            fields = Schema::FIELDS.each_with_object({}) do |key, h|
              values = @targets.map { |e| Data.has_data?(e) ? Data.read(e)[key] : Schema::DEFAULTS[key] }.uniq
              h[key] = values.size == 1 ? values.first : nil
            end
            objects = @records.map { |r| RawScanner.identity(r[:entity]).merge(dimensions: Geometry.dimensions(r[:entity], r[:transform]), source: Data.source(r[:entity]), status: Validator.validate([r]).first[:status], locked: r[:locked]) }
            emit('information', {count: @targets.size, fields: fields, objects: objects})
          when 'rules'
            emit('rules', MappingRules.read(@model))
          else
            scan_async
          end
        end
        def scan_async
          token = @generation
          @records = []
          selection = @mode == 'validate_selection'
          enumerator = Enumerator.new do |yielder|
            Scanner.walk(selection ? @model.selection.to_a : @model.entities,
                         selection ? @model.edit_transform : Geom::Transformation.new,
                         selection ? (@model.active_path || []) : []) { |r| yielder << r }
          end
          tick = nil
          tick = lambda do
            return unless token == @generation
            safely do
              check_model!
              complete = false
              begin
                300.times { @records << enumerator.next }
              rescue StopIteration
                complete = true
              end
              emit('progress', {count: @records.size})
              if complete
                finish_scan
              else
                ::UI.start_timer(0.01, false, &tick)
              end
            end
          end
          ::UI.start_timer(0.01, false, &tick)
        end
        def finish_scan
          if @mode.start_with?('validate')
            @validation = Validator.validate(@records)
            rows = @validation.each_with_index.map do |r, index|
              RawScanner.identity(r[:entity]).merge(index: index, status: r[:status], issues: r[:issues], path: r[:path].select { |e| Data.supported?(e) }.map { |e| e.name.to_s.empty? ? Geometry.definition(e).name : e.name }.join(' / '))
            end
            emit('validation', rows)
          else
            report = RawScanner.report(@records, @model)
            if @mode == 'mapping'
              @rows = Mapping.rows(@records) + Mapping.material_rows(report)
              emit('mapping', @rows.each_with_index.map { |r, index| r.reject { |k, _| k == :occurrences }.merge(index: index) })
            else
              emit('scan', report)
            end
          end
        end
        def apply(payload)
          check_model!
          check_selection!
          raise 'Select Group or Component first' if @targets.empty?
          values = Schema.normalize(payload)
          raise 'No fields enabled' if values.empty?
          targets = writable_selection
          Data.transaction(@model) { targets.each { |e| Data.write(e, values, Data.source(e) == 'RAW' ? 'MANUAL' : Data.source(e)) } }
          refresh
          emit('message', {text: "#{targets.size} objects updated; #{@targets.size - targets.size} locked objects skipped."})
        end
        def clear
          check_model!
          check_selection!
          return unless ::UI.messagebox('Clear VGD data from the selected objects?', MB_YESNO) == IDYES
          check_selection!
          targets = writable_selection
          Data.transaction(@model, 'VGD BIM Clear') { targets.each { |e| Data.erase(e) } }
          refresh
        end
        def check_selection!
          current = @model.selection.to_a.select { |e| Data.supported?(e) && e.valid? }
          raise 'Selection changed. Refresh before applying.' unless current.size == @targets.size && (current - @targets).empty?
        end
        def writable_selection
          # Explicit write-time check, never a full scan on selection-change/read.
          records = Scanner.scan_model(@model).select { |r| @targets.include?(r[:entity]) }
          blocked = records.select { |r| r[:locked] }.map { |r| r[:entity] }
          @targets.select { |e| e.valid? && !blocked.include?(e) && !e.locked? }
        end
        def preview_convert(payload)
          check_model!
          check_selection! if @mode == 'convert_selection'
          row = @mode == 'mapping' ? @rows.fetch(payload.fetch('index').to_i) : nil
          records = row ? row[:occurrences] : @records
          unless row && row[:kind] == 'material'
            entities = records.map { |r| r[:entity] }.uniq
            records = Scanner.scan_model(@model).select { |r| entities.include?(r[:entity]) }
          end
          values = Schema.normalize(payload.fetch('data'))
          rule = if row && (payload['save_rule'] || row[:kind] == 'material')
                   { 'source_type' => row[:source_type], 'source_value' => row[:source_value], 'data' => values }
                 end
          plan = Converter.preview(records, values)
          @pending = {records: records, values: values, rule: rule, token: @generation, plan: plan}
          emit('preview', {objects: plan[:entities].size, occurrences: plan[:occurrences], skipped: plan[:skipped], data: values, rule: !!rule, material: row && row[:kind] == 'material', shared: records.any? { |r| r[:path].size > 1 }})
        end
        def confirm_convert
          check_model!
          pending = @pending
          raise 'Preview expired. Preview again.' unless pending && pending[:token] == @generation
          @pending = nil
          # Re-scan at confirmation so deleted, reparented, or newly locked objects are skipped.
          current = Scanner.scan_model(@model)
          wanted = pending[:plan][:entities]
          records = current.select { |r| wanted.include?(r[:entity]) }
          # A shared nested entity is protected if ANY parent occurrence is locked.
          blocked = records.select { |r| r[:locked] }.map { |r| r[:entity] }
          records.reject! { |r| blocked.include?(r[:entity]) }
          result = Converter.convert(records, pending[:values], pending[:rule], @model)
          refresh
          emit('message', {text: "#{result[:entities].size} objects converted.#{pending[:rule] ? ' Mapping rule saved.' : ''}"})
        end
        def select_entity(index)
          check_model!
          record = @validation.fetch(index)
          raise 'Entity no longer exists. Refresh validation.' unless record[:path].all?(&:valid?)
          @model.active_path = record[:path][0...-1]
          @model.selection.clear
          @model.selection.add(record[:entity])
          bounds = Geom::BoundingBox.new
          local = Geometry.definition(record[:entity]).bounds
          8.times { |i| bounds.add(local.corner(i).transform(record[:transform])) } unless local.empty?
          @model.active_view.zoom(bounds) unless bounds.empty?
        end
      end
    end
  end
end
