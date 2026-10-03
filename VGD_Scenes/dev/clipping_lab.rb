# frozen_string_literal: true
# Manual research ONLY, excluded from the RBZ and plugin deployment.
# Load in a separate SketchUp instance containing an empty, unsaved model.
require 'sketchup.rb'
require 'json'
require 'fileutils'
module VGD
  module ScenesClippingLab
    OUTPUT = File.expand_path('../outputs/clipping_lab', __dir__)
    MARKER = 'VGD.Clipping.Lab'.freeze
    class << self
      def model
        current = Sketchup.active_model
        raise 'Lab model is not active. Never run on a working document.' unless @model && current.equal?(@model) && current.get_attribute(MARKER, 'sample') == true
        current
      end

      def build
        raise 'Lab already built in this process.' if @model
        current = Sketchup.active_model
        raise 'Use a separate instance with an empty, unsaved model (no template person).' unless current.path.empty? && current.entities.count.zero? && current.pages.count.zero? && current.active_path.nil?
        FileUtils.mkdir_p(OUTPUT)
        current.start_operation('VGD clipping research sample', true)
        begin
          room = current.entities.add_group; room.name = 'VGD LAB — room 3000 × 4000 × 2800 mm'
          box(room.entities, [0,0,-100], [3000,4000,100], 'Floor', 'Tan')
          box(room.entities, [0,0,0], [3000,100,2800], 'Front wall', 'White')
          box(room.entities, [0,3900,0], [3000,100,2800], 'Back wall', 'LightBlue')
          box(room.entities, [0,100,0], [100,3800,2800], 'Left wall', 'White')
          box(room.entities, [2900,100,0], [100,3800,2800], 'Right wall', 'White')
          box(room.entities, [950,2600,0], [1100,600,800], 'Table', 'Sienna')
          up = Geom::Vector3d.new(0,0,1)
          [['01 Outside — wall blocks view', -700], ['02 Inside — reference', 350]].each do |name, y|
            camera = Sketchup::Camera.new([1500.mm,y.mm,1500.mm], [1500.mm,2700.mm,1500.mm], up, true)
            camera.aspect_ratio = 16.0/9; camera.fov = 60
            current.active_view.camera = camera
            page = current.pages.add(name, PAGE_USE_CAMERA); page.update(PAGE_USE_CAMERA)
          end
          current.set_attribute(MARKER,'sample',true)
          current.pages.selected_page = current.pages.first
          current.commit_operation
          @model = current
          current.save(File.join(OUTPUT,'VGD_Clipping_Lab.skp'))
          snapshot('baseline')
          puts "Sample saved under #{OUTPUT}. No section plane created. Force/Near must be tested manually."
        rescue StandardError
          current.abort_operation
          raise
        end
      end

      def box(entities, origin, size, name, color)
        group = entities.add_group; group.name = name
        x,y,z = origin.map(&:mm); w,d,h = size.map(&:mm)
        face = group.entities.add_face([x,y,z],[x+w,y,z],[x+w,y+d,z],[x,y+d,z])
        face.reverse! if face.normal.z < 0
        face.pushpull(h); group.material = color
      end

      def open_debug
        model
        raise 'Windows Camera dialog only.' unless Sketchup.platform == :platform_win
        Sketchup.send_action(10624) # Undocumented action; never added to production.
      end

      def snapshot(label)
        current = model
        raise 'Use a simple, new label.' unless label.is_a?(String) && label.match?(/\A[a-z0-9_-]{1,40}\z/)
        path = File.join(OUTPUT,label+'.png')
        raise 'Snapshot exists; choose another label.' if File.exist?(path)
        current.active_view.refresh
        raise 'Could not export sample.' unless current.active_view.write_image(filename:path,width:1280,height:720,antialias:true,transparent:false)
        camera = current.active_view.camera
        report = {sketchup:Sketchup.version,ruby:RUBY_VERSION,label:label,scene:current.pages.selected_page&.name,
          eye:camera.eye.to_a,target:camera.target.to_a,fov:camera.fov,
          clipping_api:camera.public_methods.grep(/near|far|clipp/).map(&:to_s),
          note:'A screenshot alone does not prove per-scene persistence or export correctness.'}
        File.write(File.join(OUTPUT,label+'.json'),JSON.pretty_generate(report))
        path
      end
    end
  end
end
