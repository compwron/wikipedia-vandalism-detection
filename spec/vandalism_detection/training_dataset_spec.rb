require 'spec_helper'
require 'fileutils'
require 'ruby-band'

describe Wikipedia::VandalismDetection::TrainingDataset do

  before do
    use_test_configuration
    @config = test_config

    @arff_file = @config.training_output_arff_file
    @index_file = @config.training_output_index_file
    @annotations_file = @config.training_corpus_annotations_file

    @arff_files_dir = File.join(@config.output_base_directory, 'training')
  end

  after do
    if File.exists?(@arff_file)
      File.delete(@arff_file)
      FileUtils.rm_r(File.dirname @arff_file)
    end

    File.delete(@index_file) if File.exists?(@index_file)

    # remove feature arff files
    @config.features.each do |name|
      file = File.join(@arff_files_dir, name.gsub(' ', '_') + '.arff')

      if File.exists?(file)
        File.delete(file)
        FileUtils.rm_r(File.dirname file)
      end
    end
  end

  describe "#instances" do

    it "returns a weka dataset" do
      dataset = Wikipedia::VandalismDetection::TrainingDataset.instances
      dataset.class.should == Java::WekaCore::Instances
    end

    it "returns a dataset built from the configured corpus" do
      dataset = Wikipedia::VandalismDetection::TrainingDataset.instances
      filter = Weka::Filters::Unsupervised::Instance::RemoveWithValues.new

      parsed_dataset = Core::Parser.parse_ARFF(@arff_file)

      # remove instances with -1 values in features
      filter.set do
        data parsed_dataset
        filter_options '-S 0 -V'
      end

      parsed_dataset = filter.use
      puts parsed_dataset

      dataset.to_s.should == parsed_dataset.to_s
    end
  end

  describe "#uniform_instances" do

    before do
      config = test_config
      config.instance_variable_set(:@uniform_training_data, 'true')
      use_configuration(config)

      @dataset = Wikipedia::VandalismDetection::TrainingDataset.uniform_instances
    end

    it "returns a weka dataset" do
      @dataset.class.should == Java::WekaCore::Instances::Base
    end

    it "returns a dataset built from the configured corpus" do
      # 2 vandalism, 2 regular, see resources/corpora/training/annotations.csv
      @dataset.n_rows.should == 4
    end

    [:VANDALISM, :REGULAR].each do |class_const|
      it "has 2 '#{class_const.downcase}' samples in its instances" do
        class_count = @dataset.enumerate_instances.reduce(0) do |count, instance|
          label = Wikipedia::VandalismDetection::Instances::CLASSES[instance.class_value.to_i]
          (label == Wikipedia::VandalismDetection::Instances::const_get(class_const)) ? (count + 1) : count
        end

        class_count.should == 2
      end
    end
  end

  describe "#create_corpus_index_file!" do

    it "responds to #create_corpus_file_index!" do
      Wikipedia::VandalismDetection::TrainingDataset.should respond_to(:create_corpus_file_index!)
    end

    describe "exceptions" do

      it "raises an RevisionsDirectoryNotConfiguredError if no revisions directory is configured" do
        config = test_config
        config.instance_variable_set :@training_corpus_revisions_directory, nil
        use_configuration(config)

        expect { Wikipedia::VandalismDetection::TrainingDataset.create_corpus_file_index! }.to raise_error \
          Wikipedia::VandalismDetection::RevisionsDirectoryNotConfiguredError
      end
    end

    it "creates a corpus_index.yml file in the build directory" do
      File.exist?(@index_file).should be_false
      Wikipedia::VandalismDetection::TrainingDataset.create_corpus_file_index!
      File.exist?(@index_file).should be_true
    end
  end

  describe "#build!" do

    it "should respond to #build!" do
      Wikipedia::VandalismDetection::TrainingDataset.should respond_to(:build!)
    end

    describe "exceptions" do
      it "raises an EditsFileNotConfiguredError if no edits file is configured" do
        config = test_config
        config.instance_variable_set(:@training_corpus_edits_file, nil)
        use_configuration(config)

        expect { Wikipedia::VandalismDetection::TrainingDataset.build! }.to raise_error \
          Wikipedia::VandalismDetection::EditsFileNotConfiguredError
      end

      it "raises an AnnotationsFileNotConfiguredError if no annotations file is configured" do
        config = test_config
        config.instance_variable_set(:@training_corpus_annotations_file, nil)
        use_configuration(config)

        expect { Wikipedia::VandalismDetection::TrainingDataset.build! }.to raise_error \
          Wikipedia::VandalismDetection::AnnotationsFileNotConfiguredError
      end
    end

    it "creates an .arff file in the directory defined in config.yml" do
      File.exist?(@arff_file).should be_false
      Wikipedia::VandalismDetection::TrainingDataset.build!
      File.exist?(@arff_file).should be_true
    end

    Wikipedia::VandalismDetection::DefaultConfiguration::DEFAULTS['features'].each do |name|
      it "creates an arff file for the feature '#{name}'" do
        config = test_config
        config.instance_variable_set :@features, [name]
        use_configuration(config)

        file = File.join(@arff_files_dir, name.gsub(' ', '_') + '.arff')

        File.exist?(file).should be_false
        Wikipedia::VandalismDetection::TrainingDataset.build!
        File.exist?(file).should be_true
      end
    end

    it "creates only feature files that are not available yet" do
      config = test_config
      config.instance_variable_set :@features, ['anonymity', 'comment length']
      use_configuration(config)

      anonymity_file = File.join(config.output_base_directory, 'training', 'anonymity.arff')

      # create file manually, so it is existent when building dataset
      data = [10000, 'vandalism']
      anonymity = Wikipedia::VandalismDetection::Instances.empty_for_feature('anonymity')
      6.times { anonymity.add_instance(data) }
      anonymity.to_ARFF(anonymity_file)

      Wikipedia::VandalismDetection::TrainingDataset.build!

      # anonymity should not be overwritten
      Core::Parser.parse_ARFF(anonymity_file).to_a2d.first.should == data
    end

    describe "internal algorithm" do
      before do
        @features_num = @config.features.count
      end

      it "has builds the right number of data lines" do
        Wikipedia::VandalismDetection::TrainingDataset.build!
        annotations_num = File.open(@annotations_file, 'r').lines.count - 1
        additional_header_lines = 5

        File.open(@arff_file, 'r').lines.count.should == additional_header_lines + annotations_num + @features_num
      end

      it "builds the right number of data columns" do
        Wikipedia::VandalismDetection::TrainingDataset.build!
        dataset = Core::Parser.parse_ARFF @arff_file

        dataset.n_col.should == @config.features.count + 1
      end
    end
  end

  describe "#add_feature_to_arff!" do

    before do
      @feature_name = "upper to lower case ratio"
    end

    describe "exceptions" do

      it "raises an ArffFileNotFound if no arff file has been created, yet" do
        use_test_configuration

        expect { Wikipedia::VandalismDetection::TrainingDataset.add_feature_to_arff!(@feature_name) }.to raise_error \
            Wikipedia::VandalismDetection::ArffFileNotFoundError
      end

      it "raises an EditsFileNotConfiguredError if no edits file is configured" do
        config = test_config
        config.instance_variable_set :@training_corpus_edits_file, nil
        use_configuration(config)

        expect { Wikipedia::VandalismDetection::TrainingDataset.add_feature_to_arff!(@feature_name) }.to raise_error \
            Wikipedia::VandalismDetection::EditsFileNotConfiguredError
      end

      it "raises an AnnotationsFileNotConfiguredError if no annotations file is configured" do
        config = test_config
        config.instance_variable_set :@training_corpus_annotations_file, nil
        use_configuration(config)

        expect { Wikipedia::VandalismDetection::TrainingDataset.add_feature_to_arff!(@feature_name) }.to raise_error \
            Wikipedia::VandalismDetection::AnnotationsFileNotConfiguredError
      end

      it "raises a FeatureAlreadyUsedError if no feaure is alredy in arff file" do
        config = test_config
        config.instance_variable_set :@features, [@feature_name]
        use_configuration(config)

        Wikipedia::VandalismDetection::TrainingDataset.build!

        expect { Wikipedia::VandalismDetection::TrainingDataset.add_feature_to_arff!(@feature_name) }.to raise_error \
            Wikipedia::VandalismDetection::FeatureAlreadyUsedError
      end

      it "does not raise an error if text is not extractable" do
        Wikipedia::VandalismDetection::TrainingDataset.build!

        error = Wikipedia::VandalismDetection::WikitextExtractionError
        Wikipedia::VandalismDetection::WikitextExtractor.any_instance.stub(:extract) { raise(error) }

        expect { Wikipedia::VandalismDetection::TrainingDataset.add_feature_to_arff!(@feature_name) }.not_to \
            raise_error

      end
    end

    it "adds a feature to the existing arff file" do
      Wikipedia::VandalismDetection::TrainingDataset.build!
      Wikipedia::VandalismDetection::TrainingDataset.add_feature_to_arff!(@feature_name)

      features = @config.features
      features_num = features.include?(@feature_name) ? features.count : (features.count + 1)
      annotations_num = File.open(@annotations_file, 'r').lines.count - 1
      additional_header_lines = 5

      File.open(@arff_file, 'r').lines.count.should == additional_header_lines + annotations_num + features_num
    end
  end
end