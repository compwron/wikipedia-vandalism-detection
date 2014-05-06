require 'find'
require 'yaml'
require 'fileutils'
require 'active_support/core_ext/string'
require 'ruby-band'

require 'wikipedia/vandalism_detection/configuration'
require 'wikipedia/vandalism_detection/text'
require 'wikipedia/vandalism_detection/revision'
require 'wikipedia/vandalism_detection/edit'
require 'wikipedia/vandalism_detection/feature_calculator'
require 'wikipedia/vandalism_detection/features'
require 'wikipedia/vandalism_detection/instances'
require 'wikipedia/vandalism_detection/wikitext_extractor'

module Wikipedia
  module VandalismDetection

    # This class provides methods for getting and creating a training ARFF file from a configured training corpus.
    class TrainingDataset

      def self.instances
        config = Wikipedia::VandalismDetection.configuration
        arff_file = config.training_output_arff_file
        dataset = (File.exists?(arff_file) ? Core::Parser.parse_ARFF(arff_file) : build!)

        dataset = remove_invalid_instances(dataset)
        dataset.class_index = config.features.count
        dataset
      end

      def self.uniform_instances
        dataset = instances

        dataset_vandalism = Instances.empty
        dataset_regular = Instances.empty

        dataset.each_row do |instance|
          label = Instances::CLASSES[instance.class_value.to_i]
          (label == Instances::VANDALISM) ? dataset_vandalism.add(instance) : dataset_regular.add(instance)
        end

        vandalism_count = dataset_vandalism.n_rows
        regular_count = dataset_regular.n_rows
        min_count = [vandalism_count, regular_count].min

        smaller_dataset = (vandalism_count >= regular_count) ? dataset_regular : dataset_vandalism
        bigger_dataset = (vandalism_count >= regular_count) ? dataset_vandalism : dataset_regular

        while smaller_dataset.n_rows < (2 * min_count)
          random_index = SecureRandom.random_number(bigger_dataset.n_rows)
          instance = bigger_dataset.instance(random_index)

          smaller_dataset.add(instance)
          bigger_dataset.delete(random_index)
        end

        smaller_dataset
      end

      # Builds the dataset as ARFF file which can be used by a classifier.
      # As training data it uses the configured data corpus from /config/config.yml.
      def self.build!
        @config = Wikipedia::VandalismDetection.configuration
        feature_calculator = FeatureCalculator.new
        create_dataset!(feature_calculator)
      end

      # Saves and returns a file index hash of structure [file_name => full_path] for the given directory.
      def self.create_corpus_file_index!
        @config = Wikipedia::VandalismDetection.configuration
        revisions_directory = @config.training_corpus_revisions_directory

        raise RevisionsDirectoryNotConfiguredError unless revisions_directory

        print "\ncreating file index..."
        file_index = {}

        Dir.open revisions_directory do |part_directories|
          part_directories.each do |part_directory|
            Dir.open "#{revisions_directory}/#{part_directory}" do |contents|
              contents.each do |file|
                path = "#{revisions_directory}/#{part_directory}/#{file}"

                if File.file?(path) && (file =~ /\d+.txt/)
                  file_index[file] = path
                  print "\r processed #{file_index.count } files"
                end
              end
            end
          end
        end

        file = @config.training_output_index_file
        dirname = File.dirname(file)
        FileUtils.mkdir(dirname) unless Dir.exists?(dirname)

        written = File.open(file, 'w') { |f| f.write(file_index.to_yaml) }
        print "\nIndex file saved to #{file}.\n" if written > 0

        file_index
      end

      # Adds the computed values to for the given feature to the arff_file if not already available.
      def self.add_feature_to_arff!(feature_name)
        @config = Wikipedia::VandalismDetection.configuration

        annotations_file = @config.training_corpus_annotations_file
        arff_file = @config.training_output_arff_file
        edits_file = @config.training_corpus_edits_file

        raise AnnotationsFileNotConfiguredError unless annotations_file
        raise EditsFileNotConfiguredError unless edits_file
        raise ArffFileNotFoundError, "run 'rake build:features' before!" unless File.exist?(arff_file)

        print "\nadding #{feature_name} feature to the arff file ..."

        annotations = CSV.parse(File.read(annotations_file), headers: true)
        annotation_data = annotations.map { |row| { edit_id: row['editid'], class: row['class'] } }

        features_count = @config.features.count
        data_start_index = features_count + 5
        attr_name = feature_name.gsub(' ','_')

        # copy original file content to 'without_feature' file
        file_name = File.basename( arff_file, ".*" )
        dir_name = File.dirname( arff_file)
        new_file_name = "#{dir_name}/#{file_name}_without_#{attr_name}.arff"
        FileUtils.cp(arff_file, new_file_name)

        feature_class_name = feature_name.split(' ').map{ |s| s.capitalize! }.join('')
        feature_class = "Wikipedia::VandalismDetection::Features::#{feature_class_name}".constantize.new
        feature_values = []

        redirects = 0

        annotation_data.each do |row|
          edit_id = row[:edit_id]
          edit = create_edit_from edit_id

          contains_redirect = edit.old_revision.redirect? || edit.new_revision.redirect?
          if contains_redirect
            redirects += 1
          else
            value = -1

            begin
              value = feature_class.calculate(edit)
            rescue Wikipedia::VandalismDetection::WikitextExtractionError
            ensure
              feature_values << value
            end
          end

          if feature_values.count % 100 == 0
            print_progress(feature_values.count, annotation_data.count, "computing feature values")
            print " | redirects: #{redirects}" if redirects > 0
          end
        end

        print_progress(feature_values.count, annotation_data.count, "computing feature values")
        print " | redirects: #{redirects}" if redirects > 0
        print " done\n"

        new_file = File.open(arff_file, 'w')

        File.open(new_file_name, 'r').each_line.with_index do |line, index|
          raise FeatureAlreadyUsedError, "#{feature_name}is already in your arff file!" if line =~ /#{attr_name}/

          line = "#{line}@attribute #{attr_name} numeric" if index == (features_count + 1)

          if index >= data_start_index
            split = line.split(',')
            old_features = split[0...-1].join(',')
            class_value = split.last

            new_feature = feature_values[index - data_start_index]
            line = "#{old_features},#{new_feature},#{class_value}"

            if (index - data_start_index + 1) % 10 == 0
              print_progress(index - data_start_index + 1, feature_values.count, "writing features to file")
            end
          end

          new_file.puts line
        end

        new_file.close
        print " done\n"
      end

      private

      # Removes instances including -1 values
      def self.remove_invalid_instances(dataset)
        filter = Weka::Filters::Unsupervised::Instance::RemoveWithValues.new

        filter.set do
          data dataset
          filter_options '-S 0 -V'
        end

        filter.use
      end

      # Creates and returns an instance dataset from the configured gold annotation file using the
      # configured features from feature_calculator parameter.
      def self.create_dataset!(feature_calculator)
        print "\ncreating training datset..."

        annotations_file = @config.training_corpus_annotations_file
        raise AnnotationsFileNotConfiguredError unless annotations_file

        annotations = CSV.parse(File.read(annotations_file), headers: true)
        annotation_data = annotations.map { |row| { edit_id: row['editid'], class: row['class'] } }

        output_directory = File.join(@config.output_base_directory, 'training')
        FileUtils.mkdir_p(output_directory) unless Dir.exists?(output_directory)
        FileUtils.mkdir_p(@config.output_base_directory) unless Dir.exists?(@config.output_base_directory)

        merged_dataset = nil

        @config.features.each do |feature|
          feature_name = feature.gsub(' ', '_')
          file_name = "#{feature_name.downcase}.arff"
          arff_file = File.join(output_directory, file_name)

          unless File.exists?(arff_file)
            dataset = Instances.empty_for_feature(feature_name)
            dataset.to_ARFF(arff_file)

            processed_edits = 0
            skipped_edits = 0

            File.open(arff_file, 'a') do |f|
              annotation_data.each do |row|
                edit_id = row[:edit_id]
                vandalism = row[:class]

                edit = get_or_create_edit(edit_id)
                feature_value = feature_calculator.calculate_feature_for(edit, feature)
                f.puts([feature_value, vandalism].join(','))

                skipped_edits += 1 if (feature_value == -1)
                processed_edits += 1

                if processed_edits % 50 == 0
                  print_progress(processed_edits, @edits_csv.count, "#{feature} :")
                  print " | redirects: #{skipped_edits}" if skipped_edits > 0
                end
              end
            end

            puts "\n'#{File.basename(arff_file)}' saved to #{File.dirname(arff_file)}"
          end

          puts "using #{File.basename(arff_file)}"
          feature_dataset = Core::Parser.parse_ARFF(arff_file)

          if merged_dataset
            filter = Weka::Filters::Unsupervised::Attribute::Remove.new

            filter.set do
              data merged_dataset
              filter_options '-R last'
            end

            merged_dataset = filter.use
            merged_dataset = merged_dataset.merge_with(feature_dataset)
          else
            merged_dataset = feature_dataset
          end
        end

        merged_dataset.to_ARFF(@config.training_output_arff_file)
        merged_dataset
      end

      def self.get_or_create_edit(edit_id)
        @edits ||= Hash.new

        if @edits[edit_id].nil?
          @edits[edit_id] = create_edit_from(edit_id)
        end

        @edits[edit_id]
      end

      # Creates a Wikipedia::Edit out of an annotation's edit id using files form config.yml
      def self.create_edit_from(edit_id)
        @file_index ||= load_corpus_file_index
        edit_data = find_edits_data_for(edit_id)

        old_revision_id = edit_data['oldrevisionid'].to_i
        new_revision_id = edit_data['newrevisionid'].to_i

        editor = edit_data['editor']
        comment = edit_data['editcomment']

        old_revision_file = @file_index["#{old_revision_id}.txt"]
        new_revision_file = @file_index["#{new_revision_id}.txt"]

        raise(RevisionFileNotFound, "Old revision file #{old_revision_file} not found") unless \
          File.exist?(old_revision_file)
        raise(RevisionFileNotFound, "New revision file #{new_revision_file} not found") unless \
          File.exist?(new_revision_file)

        old_revision_text = File.read(old_revision_file)
        new_revision_text = File.read(new_revision_file)

        old_revision = Revision.new
        old_revision.id = old_revision_id
        old_revision.text = Text.new(old_revision_text)

        new_revision = Revision.new
        new_revision.id = new_revision_id
        new_revision.text = Text.new(new_revision_text)
        new_revision.parent_id = old_revision_id
        new_revision.comment = Text.new(comment)
        new_revision.contributor = editor

        Edit.new old_revision, new_revision
      end

      # Gets or creates the corpus index file, which holds a hash of revision files name and their path
      # in the article revisions directory.
      def self.load_corpus_file_index
        index_file = @config.training_output_index_file

        if File.exists? index_file
          puts " (Using #{index_file}) \n"
          YAML.load_file index_file
        else
          create_corpus_file_index!
        end
      end

      # Returns the line array of the edits.csv file with given edit id.
      def self.find_edits_data_for(edit_id)
        edits_file = Wikipedia::VandalismDetection.configuration.training_corpus_edits_file
        raise EditsFileNotConfiguredError unless edits_file

        @edits_file_content ||= File.read(edits_file)
        @edits_csv ||= CSV.parse(@edits_file_content, headers: true)

        edit_data = @edits_csv.find { |row| row['editid'] == edit_id }
        raise "Edit data for edit id #{edit_id} not found in #{ File.basename(edits_file) }." unless edit_data

        edit_data
      end

      # Prints the progress to the $stdout
      def self.print_progress(processed_count, total_count, message)
        processed_absolute = "#{processed_count}/#{total_count}"
        processed_percentage = "%0.2f%" % ((processed_count * 100.00) / total_count).round(2)
        print "\r#{message}... #{processed_absolute} | #{processed_percentage}"
      end
    end
  end
end