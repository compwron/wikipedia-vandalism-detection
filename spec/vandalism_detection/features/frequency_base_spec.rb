require 'spec_helper'
require 'wikipedia/vandalism_detection/features/frequency_base'

describe Wikipedia::VandalismDetection::Features::FrequencyBase do

  before do
    @feature = Wikipedia::VandalismDetection::Features::FrequencyBase.new
    @terms = Wikipedia::VandalismDetection::WordLists::PRONOUNS
  end

  it { should be_a Wikipedia::VandalismDetection::Features::Base }

  describe "#frequency" do

    it { should respond_to :frequency }

    it "returns the frequency in percentage of given word counts" do
      text = "I am, i like you."
      @feature.frequency(text , @terms).should == 3.0/5.0
    end

    it "returns 0.0 if total word count is zero" do
      @feature.frequency("", @terms).should == 0.0
    end
  end
end
