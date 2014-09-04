require "spec_helper"

module RSpec
  module Mocks
    RSpec.describe ErrorGenerator do
      describe "formatting arguments" do
        context "on non-matcher objects that define #description" do
          it "does not use the object's description" do
            o = double(:double, :description => "Friends")
            expect {
              ErrorGenerator.new(nil,nil).raise_unexpected_message_error(:foo, o)
            }.to raise_error(MockExpectationError,"nil received unexpected message :foo with (#{o.inspect})")
          end
        end

        context "on matcher objects" do
          matcher :fake_matcher do
            match { false }
          end

          context "that define description" do
            it "uses the object's description" do
              o = fake_matcher
              expect {
                ErrorGenerator.new(nil,nil).raise_unexpected_message_error(:foo, o)
              }.to raise_error(MockExpectationError,"nil received unexpected message :foo with (#{o.description})")
            end
          end

          context "that do not define description" do
            it "does not use the object's description" do
              o = fake_matcher
              allow(o).to receive(:respond_to?).and_call_original
              allow(o).to receive(:respond_to?).with(:description).and_return(false)

              expect {
                ErrorGenerator.new(nil,nil).raise_unexpected_message_error(:foo, o)
              }.to raise_error(MockExpectationError,"nil received unexpected message :foo with (#{o.inspect})")
            end
          end
        end
      end
    end
  end
end
