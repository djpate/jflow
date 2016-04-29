module JFlow
  module Activity
    class Map
      def initialize
        @map = {}
      end

      def add_activity(name, version, klass, options)
        @map ||= {}
        @map[name] ||= {}
        @map[name][version] = {:class => klass, :options => options}
      end

      def klass_for(name, version)
        return nil if !@map.has_key?(name) || !@map[name][version]
        @map[name][version][:class]
      end

      def options_for(name, version)
        return nil if !@map.has_key?(name) || !@map[name][version]
        @map[name][version][:options]
      end

    end
  end
end
