require 'active_support/core_ext/module'
require 'ruby-band'
require 'ruby-band/weka/classifiers/class_builder'
require 'pry'
require 'weka/classifiers/meta'

module Weka
  module Classifiers
    module Meta
      include ClassBuilder

      require 'java'
      require 'java/oneClassClassifier.jar'

      # One class classifier by C. Hempstalk (cite: http://dl.acm.org/citation.cfm?id=1431987)
      # Jar can be downloaded at: http://sourceforge.net/projects/weka/files/weka-packages/oneClassClassifier1.0.4.zip

      # binding.pry
      # ::ClassMethods
      def self.build_classes(*class_names)

        class_names.each do |classifier|
          including_module = self.name.demodulize.downcase #e.g. lazy, trees, ...
          java_import "weka.classifiers.#{including_module}.#{classifier}"

          module_eval <<-CLASS_DEFINITION, __FILE__, __LINE__ + 1
            class #{classifier}
              include ClassifierUtils
              class Base < #{classifier}
                def initialize(&block)
                  super
                  if block_given?
                    init_instance_classifier(&block)
                  else
                    init_classifier
                  end
                end
              end
            end
          CLASS_DEFINITION
        end
      end
      p "111111111"
      self.build_classes :MergeManyValues, :OneClassClassifier
      p "2222222"

      class OneClassClassifier

        def self.type
          "Meta::OneClassClassifier"
        end
      end
    end
  end
end
