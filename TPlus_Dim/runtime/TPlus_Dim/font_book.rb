# encoding: UTF-8
module TPlus
  module Dim
    module FontBook
      extend self
      FAMILIES = ['UTM Avo', 'Roboto', 'Roboto Condensed'].freeze unless const_defined?(:FAMILIES, false)
      FILES = %w[UTM-Avo.ttf UTM-Avobold.ttf UTM-Avoitalic.ttf UTM-Avobold-Italic.ttf
                 Roboto-Regular.ttf Roboto-Bold.ttf Roboto-Italic.ttf Roboto-BoldItalic.ttf
                 RobotoCondensed-Regular.ttf RobotoCondensed-Bold.ttf RobotoCondensed-Italic.ttf RobotoCondensed-BoldItalic.ttf].freeze unless const_defined?(:FILES, false)

      # Process-private GDI fonts; no Windows font installation or registry writes.
      def register_private
        return @status if @status
        @status = { 'loaded' => 0, 'total' => FILES.length, 'private' => false }
        return @status unless Sketchup.platform == :platform_win
        require 'fiddle'
        library = Fiddle.dlopen('gdi32.dll')
        function = Fiddle::Function.new(library['AddFontResourceExW'],
          [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT,
          defined?(Fiddle::Function::STDCALL) ? Fiddle::Function::STDCALL : Fiddle::Function::DEFAULT)
        @font_library = library
        FILES.each do |name|
          path = File.join(__dir__, 'fonts', name)
          next unless File.file?(path)
          wide_path = path.encode(Encoding::UTF_16LE).b + "\0\0".b
          @status['loaded'] += 1 if function.call(Fiddle::Pointer[wide_path], 0x10, 0) > 0
        end
        @status['private'] = @status['loaded'] == FILES.length
        @status
      rescue StandardError => error
        @status['error'] = error.message
        puts "[T+ Dim Fonts] #{error.message}"
        @status
      end

      def mesh(config)
        base = {'UTM Avo'=>'UTM-Avo', 'Roboto'=>'Roboto', 'Roboto Condensed'=>'RobotoCondensed'}.fetch(config['font'])
        suffix = if base == 'UTM-Avo'
          config['font_bold'] ? (config['font_italic'] ? 'bold-Italic' : 'bold') : (config['font_italic'] ? 'italic' : '')
        else
          config['font_bold'] ? (config['font_italic'] ? '-BoldItalic' : '-Bold') : (config['font_italic'] ? '-Italic' : '-Regular')
        end
        @meshes ||= {}
        @meshes[base+suffix] ||= JSON.parse(File.read(File.join(__dir__, 'fonts', base+suffix+'.json'), encoding: 'UTF-8'))
      end

      # Pure bundled glyph geometry: no font lookup or GDI dependency.
      def layout(text, config)
        glyphs = mesh(config).fetch('glyphs')
        height = config['size_pt'].to_f / 72.0
        x = y = 0.0
        triangles = []
        text.unicode_normalize(:nfc).each_char do |char|
          if char == "\n"
            x = 0.0; y -= height * 1.5; next
          end
          glyph = glyphs[char.ord.to_s]
          # UTM Avo's supplied cmap lacks common drawing symbols. Supplement these
          # from the bundled Roboto variant, never from a system font.
          if !glyph && [0xD8,0x2300,0xB0,0xD7,0xB7,0xB1,0x2013,0x2014,0x2026,0x2212].include?(char.ord)
            glyph = mesh(config.merge('font'=>'Roboto'))['glyphs'][(char.ord==0x2300 ? 0xD8 : char.ord).to_s]
          end
          raise ArgumentError, "Font #{config['font']} thiếu ký tự #{char.inspect}." unless glyph
          glyph['triangles'].each { |tri| triangles << tri.map { |p| [(x+p[0]*height), (y+p[1]*height), 0.0] } }
          x += glyph['advance'] * height
        end
        triangles
      end

      def draw(entities, text, config, material)
        # Scale temporarily to avoid SketchUp's small-edge tolerance for 10 pt text.
        mesh = Geom::PolygonMesh.new
        layout(text, config).each { |triangle| mesh.add_polygon(triangle.map { |p| Geom::Point3d.new(p.map { |v| v*1000.0 }) }) }
        entities.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE, material, material)
        entities.each do |entity|
          entity.hidden = true if entity.is_a?(Sketchup::Edge)
          if entity.is_a?(Sketchup::Face)
            entity.material = entity.back_material = material
          end
        end
        entities.transform_entities(Geom::Transformation.scaling(0.001), entities.to_a)
      end
    end
  end
end
