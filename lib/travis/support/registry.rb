# frozen_string_literal: true

module Travis
  module Registry
    class Registry
      def []=(key, object)
        objects[key.to_sym] = object
      end

      def [](key)
        key && objects[key.to_sym] || raise("can not use unregistered object #{key.inspect}. known objects are: #{objects.keys.inspect}")
      end

      def objects
        @objects ||= {}
      end
    end

    class << self
      def included(base)
        base.send(:extend, ClassMethods)
        base.send(:include, InstanceMethods)
      end

      def [](key)
        registries[key] ||= Registry.new
      end

      def registries
        @registries ||= {}
      end
    end

    module ClassMethods
      attr_reader :registry_key

      def [](key)
        key && registry[key.to_sym] || raise("can not use unregistered object #{key.inspect}. known objects are: #{registry.keys.inspect}")
      end

      def register(*args)
        key, namespace = *args.reverse
        registry = namespace ? Travis::Registry[namespace] : self.registry
        registry[key] = self
        @registry_key = key
        @registry_namespace = namespace
      end

      def registry
        Travis::Registry[registry_namespace]
      end

      def registry_full_key
        @registry_full_key ||= [registry_namespace, registry_key].join('.')
      end

      def registry_namespace
        @registry_namespace ||= underscore(self.class.name.split('::').last)
      end

      def underscore(string)
        string.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .downcase
      end
    end

    module InstanceMethods
      def registry_key
        self.class.registry_key
      end

      def registry_full_key
        self.class.registry_full_key
      end

      def registry_namespace
        self.class.registry_namespace
      end
    end
  end
end
