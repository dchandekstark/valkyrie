# frozen_string_literal: true
require 'spec_helper'
require 'valkyrie/specs/shared_specs'

RSpec.describe Valkyrie::Persistence::Memory::MetadataAdapter do
  let(:adapter) { described_class.new }
  it_behaves_like "a Valkyrie::MetadataAdapter"

  describe "#id" do
    it "creates a unique identifier for each instance" do
      expect(adapter.id.to_s).not_to eq described_class.new.id.to_s
    end
  end

  # rubocop:disable Metrics/LineLength
  describe "#standardize_query_result?" do
    it "throws a deprecation warning when it's set to false" do
      allow(Valkyrie.config).to receive(:standardize_query_result).and_return(false)
      expect { adapter.standardize_query_result? }.to output(/Please enable query normalization to avoid inconsistent results between different adapters by adding `standardize_query_results: true` to your environment block in config\/valkyrie.yml. This will be the behavior in Valkyrie 2.0./).to_stderr
    end
  end
  # rubocop:enable Metrics/LineLength
end
