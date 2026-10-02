# frozen_string_literal: true
module VGD
  module Scenes
    module SceneFrame
      KEYS = %w[width height margin].freeze

      def self.read(page, fallback)
        saved = JSON.parse(page.get_attribute(DICT, 'frame', '{}'))
        if KEYS.all? { |key| saved.key?(key) }
          return Scenes.options(fallback.merge(saved.select { |key, _| KEYS.include?(key) })).select { |key, _| KEYS.include?(key) }
        end
        source = SceneStore.owned?(page) ? SceneStore.metadata(page)['options'] : nil
        opts = source.is_a?(Hash) ? fallback.merge(source) : fallback
        from_camera(page.camera, opts)
      end

      def self.from_camera(camera, opts)
        aspect = camera.aspect_ratio
        return opts.select { |key, _| KEYS.include?(key) } unless aspect > 0
        edge = [opts['width'], opts['height']].max.to_f
        width, height = aspect >= 1 ? [edge, edge / aspect] : [edge * aspect, edge]
        { 'width' => width.round, 'height' => height.round, 'margin' => opts['margin'] }
      end

      def self.store(page, opts)
        page.set_attribute(DICT, 'frame', opts.select { |key, _| KEYS.include?(key) }.to_json)
      end
    end

    class FrameTool
      @active = nil
      @suspended = false
      class << self
        attr_accessor :suspended
        def active?
          !@active.nil?
        end
        def attach(instance)
          @active = instance
          Scenes.sync_frame if Scenes.respond_to?(:sync_frame)
        end
        def detach(instance)
          @active = nil if @active == instance
          Scenes.sync_frame if Scenes.respond_to?(:sync_frame)
        end
        def toggle(model, opts)
          if @active && @active.model == model
            model.select_tool(nil)
          else
            model.select_tool(new(model, opts['grid']))
          end
        end
      end
      attr_reader :model
      def initialize(model, grid)
        @model = model; @grid = grid
      end
      def activate
        self.class.attach(self); @model.active_view.invalidate
      end
      def deactivate(view)
        self.class.detach(self); view.invalidate
      end
      def resume(view)
        self.class.attach(self); view.invalidate
      end
      def onCancel(_reason, view)
        @model.select_tool(nil); view.invalidate
      end
      def onKeyDown(key, _repeat, _flags, _view)
        @model.select_tool(nil) if key == 27
      end
      def draw(view)
        return if self.class.suspended
        width = view.vpwidth.to_f; height = view.vpheight.to_f
        ratio = view.camera.aspect_ratio
        ratio = width / height if ratio <= 0.0
        fw = [width, height * ratio].min; fh = fw / ratio
        x = (width - fw) / 2.0; y = (height - fh) / 2.0
        view.drawing_color = Sketchup::Color.new(180, 137, 99, 220)
        view.line_width = 1
        factors = case @grid
                  when 'thirds' then [1.0 / 3, 2.0 / 3]
                  when 'golden' then [0.381966, 0.618034]
                  when 'center' then [0.5]
                  when 'grid4' then [0.25, 0.5, 0.75]
                  else []
                  end
        lines = factors.flat_map { |f| [[x + fw * f, y, 0], [x + fw * f, y + fh, 0], [x, y + fh * f, 0], [x + fw, y + fh * f, 0]] }
        view.draw2d(GL_LINES, lines) unless lines.empty?
        view.draw_text(Geom::Point3d.new(x + 10, y + 10, 0), 'VGD · Lưới bố cục | Orbit: chuột giữa · Esc: tắt lưới', color: Sketchup::Color.new(180, 137, 99))
      end
    end

    def self.apply_frame(model, opts, fit = false, save = !fit)
      target = Geometry.target(model, Geometry.selection_paths(model), opts['axis_mode']) if fit
      action = lambda do
        if fit
          Geometry.fit_current(model, target, opts)
        else
          camera = camera_copy(model.active_view.camera)
          camera.aspect_ratio = opts['width'].to_f / opts['height']
          model.active_view.camera = camera
        end
        page = model.pages.selected_page
        if save && page
          page.use_camera = true
          raise 'Không lưu được khung vào scene hiện tại.' unless page.update(PAGE_USE_CAMERA)
          SceneFrame.store(page, opts)
        end
        model.set_attribute(DICT, 'working_frame', opts.select { |key, _| SceneFrame::KEYS.include?(key) }.to_json) if save
      end
      save ? Scenes.operation(model, 'Áp dụng và lưu khung', &action) : action.call
      model.active_view.invalidate
      { success: true, message: save ? (model.pages.selected_page ? 'Đã áp dụng và lưu khung vào scene hiện tại.' : 'Đã áp dụng khung. Chưa có scene để lưu.') : 'Đã xem trước khung trên view hiện tại. Chưa lưu scene; bấm Áp dụng khung để lưu.' }
    end

    def self.toggle_frame(model, opts)
      if model.active_view.camera.aspect_ratio > 0
        camera = camera_copy(model.active_view.camera)
        camera.aspect_ratio = 0.0
        model.active_view.camera = camera
        model.active_view.invalidate
        { success: true, message: 'Đã tắt khung canh view, trở về khung nhìn SketchUp. Khung scene đã lưu không đổi.' }
      else
        apply_frame(model, opts, false, false)
      end
    end
  end
end
