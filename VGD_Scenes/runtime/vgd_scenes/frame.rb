# frozen_string_literal: true
module VGD
  module Scenes
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
        view.draw2d(GL_LINE_LOOP, [[x, y, 0], [x + fw, y, 0], [x + fw, y + fh, 0], [x, y + fh, 0]])
        factors = case @grid
                  when 'thirds' then [1.0 / 3, 2.0 / 3]
                  when 'golden' then [0.381966, 0.618034]
                  when 'center' then [0.5]
                  when 'grid4' then [0.25, 0.5, 0.75]
                  else []
                  end
        lines = factors.flat_map { |f| [[x + fw * f, y, 0], [x + fw * f, y + fh, 0], [x, y + fh * f, 0], [x + fw, y + fh * f, 0]] }
        view.draw2d(GL_LINES, lines) unless lines.empty?
        view.draw_text(Geom::Point3d.new(x + 10, y + 10, 0), 'VGD · Khung xuất | Orbit: chuột giữa · Esc: tắt lưới', color: Sketchup::Color.new(180, 137, 99))
      end
    end

    def self.apply_frame(model, opts, fit = false)
      if fit
        target = Geometry.target(model, Geometry.selection_paths(model), opts['axis_mode'])
        kind = opts['views'].first || 'ISO'
        Geometry.fit(model, target, kind, opts)
      else
        camera = camera_copy(model.active_view.camera)
        camera.aspect_ratio = opts['width'].to_f / opts['height']
        model.active_view.camera = camera
      end
      model.active_view.invalidate
      { success: true, message: fit ? 'Đã căn đối tượng theo khung xuất.' : 'Đã áp dụng tỷ lệ khung cho camera hiện tại. Lưu vào scene để giữ bố cục.' }
    end
  end
end
