require 'spec_helper'

module RSpec::Core

  describe SharedExampleGroup do
    it "should add the 'share_examples_for' method to the global namespace" do
      Kernel.should respond_to(:share_examples_for)
    end

    it "should add the 'shared_examples_for' method to the global namespace" do
      Kernel.should respond_to(:shared_examples_for)
    end

    it "should add the 'share_as' method to the global namespace" do
      Kernel.should respond_to(:share_as)
    end

    it "should raise an ArgumentError when adding a second shared example group with the same name" do
      group = ExampleGroup.describe('example group')
      group.share_examples_for('really important business value') { }
      lambda do
        group.share_examples_for('really important business value') { }
      end.should raise_error(ArgumentError, "Shared example group 'really important business value' already exists")
    end

    describe "share_examples_for" do

      it "should capture the given name and block in the Worlds collection of shared example groups" do
        RSpec.world.shared_example_groups.should_receive(:[]=).with(:foo, anything)
        share_examples_for(:foo) { }
      end

    end

    describe "including shared example_groups using #it_should_behave_like" do

      it "should make any shared example_group available at the correct level" do
        group = ExampleGroup.describe('fake group')
        block = lambda {
          def self.class_helper; end
          def extra_helper; end
        }
        RSpec.world.stub(:shared_example_groups).and_return({ :shared_example_group => block })
        shared_group = group.it_should_behave_like(:shared_example_group).first
        shared_group.instance_methods.map {|m| m.to_s }.should  include('extra_helper')
        shared_group.singleton_methods.map {|m| m.to_s}.should include('class_helper')
      end

      it "raises when named shared example_group can not be found" do
        group = ExampleGroup.describe("example_group")
        lambda do
          group.it_should_behave_like("a group that does not exist")
        end.should raise_error(/Could not find shared example group named/)
      end

      it "does not add examples to current example_group using it_should_behave_like" do
        group = ExampleGroup.describe("example_group") do
          it("i was already here") {}
        end

        group.examples.size.should == 1

        group.share_examples_for('shared example_group') do
          it("shared example") {}
          it("shared example 2") {}
        end

        group.it_should_behave_like("shared example_group")

        group.examples.size.should == 1
      end

      it "adds examples to current example_group using include", :compat => 'rspec-1.2' do
        share_as('Cornucopia') do
          it "is plentiful" do
            5.should == 4
          end
        end
        group = ExampleGroup.describe('group') { include Cornucopia }
        group.examples.length.should == 1
        group.examples.first.metadata[:description].should == "is plentiful"
      end

      it "adds the helper methods from the block provided to it_should_behave_like" do
        group = ExampleGroup.describe("example group") {}
        group.shared_examples_for("shared group") {}
        shared_groups = group.it_should_behave_like("shared group") do
          def helper_method; end
          def self.class_helper; end
        end

        shared_group = shared_groups.first

        shared_group.instance_methods.map { |m| m.to_sym }.should include(:helper_method)
        shared_group.singleton_methods.map { |m| m.to_sym }.should include(:class_helper)
      end

      it "overrides the instance helper methods with the definitions from the block provided to it_should_behave_like" do
        pending("decide that we really want this behavior")
        group = ExampleGroup.describe("example group") {}
        group.shared_examples_for("shared group") do
          def helper_method; 'base helper'; end
        end

        shared_groups = group.it_should_behave_like("shared group") do
          def helper_method; [super, 'overridden helper'].join('; '); end
        end

        shared_groups.first.new.helper_method.should == 'base helper; overridden helper'
      end

      it "overrides the class helper methods with the definitions from the block provided to it_should_behave_like" do
        pending("decide that we really want this behavior")
        group = ExampleGroup.describe("example group") {}
        group.shared_examples_for("shared group") do
          def self.helper_method; 'base helper'; end
        end

        shared_groups = group.it_should_behave_like("shared group") do
          def self.helper_method; [super, 'overridden helper'].join('; '); end
        end

        shared_groups.first.helper_method.should == 'base helper; overridden helper'
      end

      it "allows the RSpec DSL to be used in the block provided to it_should_behave_like" do
        results = {}
        group = ExampleGroup.describe("example group") {}
        group.shared_examples_for("shared group") do
          it 'assigns the results of using the RSpec DSL' do
            results[:subject] = subject
            results[:foo] = foo
            results[:before_each] = @before_each
          end
        end

        group.it_should_behave_like("shared group") do
          subject { :the_subject }
          let(:foo) { :foo_value }
          before(:each) { @before_each = :before_each_ivar }
        end

        group.run_all
        results.should == {
          :subject     => :the_subject,
          :foo         => :foo_value,
          :before_each => :before_each_ivar
        }
      end

      describe "running shared examples", :pending => true do
        module ::RunningSharedExamplesJustForTesting; end

        let(:group) do
          ExampleGroup.describe("example group")
        end

        before(:each) do
          group.share_examples_for("it runs shared examples") do
            include ::RunningSharedExamplesJustForTesting

            class << self
              def magic
                $magic ||= {}
              end

              def count(scope)
                @counters ||= {
                  :before_all  => 0,
                  :before_each => 0,
                  :after_each  => 0,
                  :after_all   => 0
                }
                @counters[scope] += 1
              end
            end

            # TODO - necessary?
            def magic
              $magic ||= {}
            end

            def count(scope)
              self.class.count(scope)
            end

            before(:all)  { magic[:before_all]  = "before all #{count(:before_all)}" }
            before(:each) { magic[:before_each] = "before each #{count(:before_each)}" }
            after(:each)  { magic[:after_each]  = "after each #{count(:after_each)}" }
            after(:all)   { magic[:after_all]   = "after all #{count(:after_all)}" }
          end
        end

        before do
          group.it_should_behave_like "it runs shared examples"
          group.it "has one example" do; end
          group.it "has another example" do; end
          group.it "includes modules, included into shared example_group, into current example_group", :compat => 'rspec-1.2' do
            raise "FAIL" unless example.example_group.included_modules.include?(RunningSharedExamplesJustForTesting)
          end
          group.run_all
        end

        let(:shared_group) { group.children.first }

        it "runs before(:all) only once from shared example_group", :compat => 'rspec-1.2' do
          shared_group.magic[:before_all].should eq("before all 1")
        end

        it "runs before(:each) from shared example_group", :compat => 'rspec-1.2' do
          group.magic[:before_each].should eq("before each 3")
        end

        it "runs after(:each) from shared example_group", :compat => 'rspec-1.2' do
          group.magic[:after_each].should eq("after each 3")
        end

        it "runs after(:all) only once from shared example_group", :compat => 'rspec-1.2' do
          group.magic[:after_all].should eq("after all 1")
        end

        it "makes methods defined in the shared example_group available in consuming example_group", :compat => 'rspec-1.2' do
          group.magic.should be_a(Hash)
        end

      end

    end

  end

end