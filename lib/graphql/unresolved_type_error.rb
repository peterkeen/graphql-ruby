module GraphQL
  # Error raised when the value provided for a field can't be resolved to one of the possible types
  # for the field.
  class UnresolvedTypeError < GraphQL::Error
    def initialize(field_name, schema, field_type, parent_type, received_type)
      possible_types = field_type.kind.resolves? ? schema.possible_types(field_type) : [field_type]
      message = %|The value from "#{field_name}" on "#{parent_type}" could not be resolved to "#{field_type}". (Received: #{received_type.inspect}, Expected: [#{possible_types.map(&:inspect).join(", ")}])|
      super(message)
    end
  end

  class ObjectType
    # @deprecated Use {GraphQL::UnresolvedTypeError} instead
    UnresolvedTypeError = GraphQL::UnresolvedTypeError
  end
end
