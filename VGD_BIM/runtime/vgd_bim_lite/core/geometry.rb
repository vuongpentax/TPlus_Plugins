module VGD
  module BIM
    module Geometry
      INCH_MM = 25.4
      def self.definition(entity)
        entity.is_a?(Sketchup::Group) ? entity.entities.parent : entity.definition
      end
      # Local axes dimensions after full occurrence transform; rotation preserves W/D/H.
      def self.dimensions(entity, transform = nil)
        transform ||= entity.transformation
        box = definition(entity).bounds
        return {width: 0.0, depth: 0.0, height: 0.0} if box.empty?
        {width: box.width.to_f * transform.xaxis.length * INCH_MM,
         depth: box.height.to_f * transform.yaxis.length * INCH_MM,
         height: box.depth.to_f * transform.zaxis.length * INCH_MM}
      end
      def self.width(entity, transform = nil); dimensions(entity, transform)[:width]; end
      def self.depth(entity, transform = nil); dimensions(entity, transform)[:depth]; end
      def self.height(entity, transform = nil); dimensions(entity, transform)[:height]; end
      def self.face_area(face, transform = Geom::Transformation.new)
        face.area(transform).to_f * INCH_MM**2 / 1_000_000.0
      end
      def self.edge_length(edge, transform = Geom::Transformation.new)
        edge.start.position.transform(transform).distance(edge.end.position.transform(transform)).to_f * INCH_MM / 1000.0
      end
    end
  end
end
