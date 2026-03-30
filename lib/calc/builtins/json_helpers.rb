module Calc
  class Builtins
    # Helpers for parsing and serializing JSON values in Calc-compatible form.
    module JsonHelpers
      # Parses a JSON string value and converts it into Calc's internal representation.
      #
      # @param value [String] The JSON string to parse.
      # @return [Object] The Calc-compatible representation of the JSON value.
      # @raise [Calc::RuntimeError] If the input is not a string.
      # @raise [Calc::SyntaxError] If the JSON string is malformed.
      def parse_json_value(value)
        raise Calc::RuntimeError, "parse-json expects a string" unless value.is_a?(String)

        JSON.parse(value, symbolize_names: false, decimal_class: BigDecimal).then { |parsed| convert_json_to_calc(parsed) }
      rescue JSON::ParserError => e
        raise Calc::SyntaxError, e.message
      end

      # Recursively converts Calc's internal data types into JSON-serializable types.
      # Handles BigDecimal to Float/Integer conversion for JSON compatibility.
      #
      # @param value [Object] The Calc value to jsonify.
      # @return [Object] The JSON-serializable representation.
      def jsonify_value(value)
        case value
        when Array
          value.map { |item| jsonify_value(item) }
        when Hash
          value.each_with_object({}) do |(key, item), result|
            result[key.to_s] = jsonify_value(item)
          end
        when BigDecimal
          float_value = value.to_f
          return value.to_i if value.frac.zero? && value.abs <= BigDecimal(Float::MAX.to_s)
          return float_value if float_value.finite? && BigDecimal(float_value.to_s) == value

          value.to_s("F")
        else
          value
        end
      end

      private

      # Recursively converts parsed JSON values into Calc's internal data types.
      #
      # @param value [Object] The value parsed from JSON.
      # @return [Object] The Calc-compatible representation.
      def convert_json_to_calc(value)
        case value
        when Array
          value.map { |item| convert_json_to_calc(item) }
        when Hash
          value.each_with_object({}) do |(key, item), result|
            result[key] = convert_json_to_calc(item)
          end
        when Integer, BigDecimal
          BigDecimal(value.to_s)
        else
          value
        end
      end
    end
  end
end
