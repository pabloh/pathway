# frozen_string_literal: true

require 'spec_helper'

module Pathway
  describe Result do

    describe ".success" do
      let(:result) { Result.success("VALUE") }
      it "returns a Success object with passed value", :aggregate_failures do
        expect(result).to be_a(Result::Success)
        expect(result.value).to eq("VALUE")
      end
    end

    describe ".failure" do
      let(:result) { Result.failure("ERROR!") }
      it "returns a Failure object with passed value", :aggregate_failures do
        expect(result).to be_a(Result::Failure)
        expect(result.error).to eq("ERROR!")
      end
    end

    describe ".result" do
      let(:result) { Result.result(object) }
      context "when passing a Result object" do
        let(:object) { Result.failure(:something_went_wrong) }
        it "returns the object itsef" do
          expect(result).to eq(object)
        end
      end

      context "when passing a regular object" do
        let(:object) { "SOME VALUE" }
        it "returns the object wrapped in a result", :aggregate_failures do
          expect(result).to be_a(Result::Success)
          expect(result.value).to eq("SOME VALUE")
        end
      end
    end

    context "when is a success" do
      subject(:prev_result) { Result.success("VALUE") }
      describe "#success?" do
        it { expect(prev_result.success?).to be true }
      end

      describe "#failure?" do
        it { expect(prev_result.failure?).to be false }
      end

      describe "#then" do
        let(:callable) { double }
        let(:next_result) { Result.success("NEW VALUE")}
        before { expect(callable).to receive(:call).with("VALUE").and_return(next_result) }

        it "if a block is given it executes it and returns the new result" do
          expect(prev_result.then { |prev| callable.call(prev) }).to eq(next_result)
        end

        it "if a callable is given it executes it and returns the new result" do
          expect(prev_result.then(callable)).to eq(next_result)
        end
      end

      describe "#tee" do
        let(:callable) { double }
        let(:next_result) { Result.success("NEW VALUE")}
        before { expect(callable).to receive(:call).with("VALUE").and_return(next_result) }

        it "if a block is given it executes it and keeps the previous result" do
          expect(prev_result.tee { |prev| callable.call(prev) }).to eq(prev_result)
        end

        context "when a block wich returns an unwrapped result is given" do
          let(:next_result) { "NEW VALUE" }
          it "it executes it and keeps the previous result" do
            expect(prev_result.tee { |prev| callable.call(prev) }).to eq(prev_result)
          end
        end

        it "if a callable is given it executes it and keeps the previous result" do
          expect(prev_result.tee(callable)).to eq(prev_result)
        end
      end
    end

    context "when is a failure" do
      subject(:prev_result) { Result.failure(:something_wrong) }
      describe "#success?" do
        it { expect(prev_result.success?).to be false }
      end

      describe "#failure?" do
        it { expect(prev_result.failure?).to be true }
      end

      describe "#tee" do
        let(:callable) { double }
        before { expect(callable).to_not receive(:call) }

        it "if a block is given it ignores it and returns itself" do
          expect(prev_result.tee { |prev| callable.call(prev) }).to eq(prev_result)
        end

        it "if a callable is given it ignores it and returns itself" do
          expect(prev_result.tee(callable)).to eq(prev_result)
        end
      end

      describe "#then" do
        let(:callable) { double }
        before { expect(callable).to_not receive(:call) }

        it "if a block is given it ignores it and returns itself" do
          expect(prev_result.then { |prev| callable.call(prev) }).to eq(prev_result)
        end

        it "if a callable is given it ignores it and returns itself" do
          expect(prev_result.then(callable)).to eq(prev_result)
        end
      end
    end

  end
end
