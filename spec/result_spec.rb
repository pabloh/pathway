# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pathway::Result do
  describe ".success" do
    subject(:result) { described_class.success("VALUE") }
    it "returns a Success object with passed value", :aggregate_failures do
      expect(result).to be_a(Pathway::Result::Success)
      expect(result.value).to eq("VALUE")
    end
  end

  describe ".failure" do
    subject(:result) { described_class.failure("ERROR!") }
    it "returns a Failure object with passed value", :aggregate_failures do
      expect(result).to be_a(Pathway::Result::Failure)
      expect(result.error).to eq("ERROR!")
    end
  end

  describe ".result" do
    subject(:result) { described_class.result(object) }
    context "when passing a Result object" do
      let(:object) { described_class.failure(:something_went_wrong) }
      it "returns the object itsef" do
        expect(result).to eq(object)
      end
    end

    context "when passing a regular object" do
      let(:object) { "SOME VALUE" }
      it "returns the object wrapped in a result", :aggregate_failures do
        expect(result).to be_a(Pathway::Result::Success)
        expect(result.value).to eq("SOME VALUE")
      end
    end
  end

  describe "Success" do
    subject(:result) { described_class.success("VALUE") }
    describe "#success?" do
      it { expect(result.success?).to be true }
    end

    describe "#failure?" do
      it { expect(result.failure?).to be false }
    end

    describe "#then" do
      let(:callable) { double }
      let(:next_result) { described_class.success("NEW VALUE") }
      before { expect(callable).to receive(:call).with("VALUE").and_return(next_result) }

      it "if a block is given it executes it and returns the new result" do
        expect(result.then { |prev| callable.call(prev) }).to eq(next_result)
      end

      it "if a callable is given it executes it and returns the new result" do
        expect(result.then(callable)).to eq(next_result)
      end
    end

    describe "#tee" do
      let(:callable) { double }
      let(:next_result) { described_class.success("NEW VALUE") }
      before { expect(callable).to receive(:call).with("VALUE").and_return(next_result) }

      it "if a block is given it executes it and keeps the previous result" do
        expect(result.tee { |prev| callable.call(prev) }).to eq(result)
      end

      context "when a block wich returns an unwrapped result is given" do
        let(:next_result) { "NEW VALUE" }
        it "it executes it and keeps the previous result" do
          expect(result.tee { |prev| callable.call(prev) }).to eq(result)
        end
      end

      it "if a callable is given it executes it and keeps the previous result" do
        expect(result.tee(callable)).to eq(result)
      end
    end
  end

  describe "Failure" do
    subject(:result) { described_class.failure(:something_wrong) }
    describe "#success?" do
      it { expect(result.success?).to be false }
    end

    describe "#failure?" do
      it { expect(result.failure?).to be true }
    end

    describe "#tee" do
      let(:callable) { double }
      before { expect(callable).to_not receive(:call) }

      it "if a block is given it ignores it and returns itself" do
        expect(result.tee { |prev| callable.call(prev) }).to eq(result)
      end

      it "if a callable is given it ignores it and returns itself" do
        expect(result.tee(callable)).to eq(result)
      end
    end

    describe "#then" do
      let(:callable) { double }
      before { expect(callable).to_not receive(:call) }

      it "if a block is given it ignores it and returns itself" do
        expect(result.then { |prev| callable.call(prev) }).to eq(result)
      end

      it "if a callable is given it ignores it and returns itself" do
        expect(result.then(callable)).to eq(result)
      end
    end
  end
end
