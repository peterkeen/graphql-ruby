require "spec_helper"

describe GraphQL::Query::Arguments do
  let(:arguments) {
    test_input_1 = GraphQL::InputObjectType.define do
      name "TestInput1"
      argument :d, types.Int
      argument :e, types.Int
    end

    test_input_2 = GraphQL::InputObjectType.define do
      name "TestInput2"
      argument :a, types.Int
      argument :b, types.Int
      argument :c, !test_input_1
    end

    GraphQL::Query::Arguments.new({
      a: 1,
      b: 2,
      c: GraphQL::Query::Arguments.new({
        d: 3,
        e: 4,
      }, argument_definitions: test_input_1.arguments),
    }, argument_definitions: test_input_2.arguments)
  }

  it "returns keys as strings" do
    assert_equal(["a", "b", "c"], arguments.keys)
  end

  it "delegates values to values hash" do
    assert_equal([1, 2, {"d" => 3, "e" => 4}], arguments.values)
  end

  it "delegates each to values hash" do
    pairs = []
    arguments.each do |key, value|
      pairs << [key, value]
    end
    assert_equal([["a", 1], ["b", 2], ["c", {"d" => 3, "e" => 4}]], pairs)
  end

  it "returns original Ruby hash values with to_h" do
    assert_equal({ a: 1, b: 2, c: { d: 3, e: 4 } }, arguments.to_h)
  end

  describe "nested hashes" do
    let(:input_type) {
      test_input_type = GraphQL::InputObjectType.define do
        name "TestInput"
        argument :a, types.Int
        argument :b, test_input_type
        argument :c, types.Int # will be a hash
      end
    }
    it "wraps input objects, but not other hashes" do
      args = GraphQL::Query::Arguments.new(
        {a: 1, b: {a: 2}, c: {a: 3}},
        argument_definitions: input_type.arguments
      )
      assert args["b"].is_a?(GraphQL::Query::Arguments)
      assert args["c"].is_a?(Hash)
    end
  end

  describe "#key?" do
    let(:arg_values) { [] }
    let(:schema) {
      arg_values_array = arg_values

      test_input_type = GraphQL::InputObjectType.define do
        name "TestInput"
        argument :a, types.Int
        argument :b, types.Int, default_value: 2
        argument :c, types.Int
        argument :d, types.Int
      end

      query = GraphQL::ObjectType.define do
        name "Query"
        field :argTest, types.Int do
          argument :a, types.Int
          argument :b, types.Int, default_value: 2
          argument :c, types.Int
          argument :d, test_input_type
          resolve ->(obj, args, ctx) {
            arg_values_array << args
            1
          }
        end
      end

      GraphQL::Schema.define(query: query)
    }

    it "detects missing keys by string or symbol" do
      assert_equal true, arguments.key?(:a)
      assert_equal true, arguments.key?("a")
      assert_equal false, arguments.key?(:f)
      assert_equal false, arguments.key?("f")
    end

    it "works from query literals" do
      schema.execute("{ argTest(a: 1) }")

      last_args = arg_values.last

      assert_equal true, last_args.key?(:a)
      # This is present from default value:
      assert_equal true, last_args.key?(:b)
      assert_equal false, last_args.key?(:c)
      assert_equal({"a" => 1, "b" => 2}, last_args.to_h)
    end

    it "works from variables" do
      variables = { "arg" => { "a" => 1, "d" => nil } }
      schema.execute("query ArgTest($arg: TestInput){ argTest(d: $arg) }", variables: variables)

      test_inputs = arg_values.last["d"]

      assert_equal true, test_inputs.key?(:a)
      # This is present from default value:
      assert_equal true, test_inputs.key?(:b)

      assert_equal false, test_inputs.key?(:c)
      # This _was_ present in the variables,
      # but it was nil, which is not allowed in GraphQL
      assert_equal false, test_inputs.key?(:d)

      assert_equal({"a" => 1, "b" => 2}, test_inputs.to_h)
    end

    it "works with variable default values" do
      schema.execute("query ArgTest($arg: TestInput = {a: 1}){ argTest(d: $arg) }")

      test_defaults = arg_values.last["d"]

      assert_equal true, test_defaults.key?(:a)
      # This is present from default val
      assert_equal true, test_defaults.key?(:b)

      assert_equal false, test_defaults.key?(:c)
      assert_equal false, test_defaults.key?(:d)
      assert_equal({"a" => 1, "b" => 2}, test_defaults.to_h)
    end
  end
end
