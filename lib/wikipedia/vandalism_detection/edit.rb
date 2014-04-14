module Wikipedia
  module VandalismDetection
    class Edit

      attr_reader :old_revision, :new_revision

      def initialize(old_revision, new_revision)
        message = "old revision: #{old_revision.id} | parent: #{old_revision.parent_id},
                  new revision: #{new_revision.id} | parent: #{new_revision.parent_id}"
        raise ArgumentError, "Revisions are not sequent: #{message}." if !sequent?(old_revision, new_revision)

        @old_revision = old_revision
        @new_revision = new_revision
      end

      def serialize(*attributes)
        old_revision_parts = []
        new_revision_parts = []

        attributes.each do |attr|
          variable_name = "@#{attr.to_s}"

          if @old_revision.instance_variable_defined?(variable_name)
            old_revision_parts.push @old_revision.instance_variable_get(variable_name)
          end
        end

        attributes.each do |attr|
          variable_name = "@#{attr.to_s}"
          if @new_revision.instance_variable_defined?(variable_name)
            new_revision_parts.push @new_revision.instance_variable_get(variable_name)
          end
        end

        old_revision_string = old_revision_parts.join ':'
        new_revision_string = new_revision_parts.join ':'

        "#{old_revision_string}\t#{new_revision_string}"
      end

      private

      def sequent?(old_revision, new_revision)
        new_revision.parent_id == old_revision.id
      end
    end
  end
end