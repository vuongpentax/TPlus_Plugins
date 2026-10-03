# frozen_string_literal: true
module VGD
  module Scenes
    module CameraControl
      def self.state(model)
        camera = model.active_view.camera
        { eye_z_mm: camera.eye.z.to_f * 25.4, perspective: camera.perspective?,
          supported: !SceneTransfer.two_point?(camera) }
      end

      def self.elevation(model, raw)
        raise ArgumentError, 'Thông số camera không hợp lệ.' unless raw.is_a?(Hash)
        raise 'Đóng edit Group/Component trước khi chỉnh camera.' if model.active_path
        original = model.active_view.camera
        raise 'Đổi sang Perspective hoặc Parallel Projection trước khi chỉnh cao độ. Chưa hỗ trợ hai điểm / Match Photo.' if SceneTransfer.two_point?(original)
        mode = raw['mode']
        raise ArgumentError, 'Chế độ cao độ không hợp lệ.' unless %w[absolute floor].include?(mode)
        z = if mode == 'absolute'
              Scenes.number(raw['z'], -1e9, 1e9, 'Cao độ mắt (mm)')
            else
              floor = Scenes.number(raw['floor'], -1e9, 1e9, 'Cao độ sàn (mm)')
              height = Scenes.number(raw['height'], 0, 1e6, 'Eye Height (mm)')
              Scenes.number(floor + height, -1e9, 1e9, 'Cao độ mắt (mm)')
            end
        raise ArgumentError, 'Chọn cách giữ hướng nhìn.' unless [true, false].include?(raw['keep_direction'])
        eye = original.eye.to_a; target = original.target.to_a
        delta = z / 25.4 - eye[2]
        eye[2] += delta
        target[2] += delta if raw['keep_direction']
        direction = Geom::Point3d.new(target) - Geom::Point3d.new(eye)
        raise ArgumentError, 'Cao độ làm hướng nhìn không hợp lệ. Bật Giữ hướng nhìn hoặc chọn cao độ khác.' if direction.length < 1e-9 || direction.normalize.cross(original.up.normalize).length < 1e-9
        camera = Sketchup::Camera.new(Geom::Point3d.new(eye), Geom::Point3d.new(target), original.up, original.perspective?)
        camera.aspect_ratio = original.aspect_ratio
        if original.perspective?
          fov = original.fov
          if camera.fov_is_height? != original.fov_is_height?
            aspect = original.aspect_ratio
            aspect = model.active_view.vpwidth.to_f / model.active_view.vpheight if aspect <= 0
            tangent = Math.tan(fov * Math::PI / 360)
            tangent = original.fov_is_height? ? tangent * aspect : tangent / aspect
            fov = Math.atan(tangent) * 360 / Math::PI
          end
          camera.fov = fov
        else
          camera.height = original.height
        end
        model.active_view.camera = camera
        model.active_view.invalidate
        { success: true, message: "Đã xem trước cao độ mắt #{z.round(2)} mm theo Z thế giới. Bấm Cập nhật view để lưu vào scene." }
      end
    end
  end
end
