require "bigdecimal"
require "date"
require "time"

module Calc
  module Functions
    module Time
      # This module registers built-in functions for time and date manipulation.
      # All time values are represented internally as epoch microseconds (BigDecimal).
      USEC_PER_SECOND = 1_000_000

      # Registers all time-related functions with the Builtins registry.
      #
      # @param builtins [Builtins] The Builtins instance to register functions with.
      def self.register(builtins)
        register_current_time(builtins)
        register_parse_time(builtins)
        register_format_time(builtins)
        register_month_shift(builtins)
        register_month_boundaries(builtins)
      end

      # Registers the `current-time` function.
      #
      # @param builtins [Builtins] The Builtins instance.
      def self.register_current_time(builtins)
        # Returns the current UTC time as epoch microseconds: `(current-time)`
        Functions.register(builtins, "current-time", min_arity: 0, max_arity: 0) { |_args| to_epoch_usec(::Time.now.utc) }
      end

      # Registers the `parse-time` function.
      #
      # @param builtins [Builtins] The Builtins instance.
      def self.register_parse_time(builtins)
        # Parses a time string into epoch microseconds: `(parse-time "2026-03-27T12:34:56Z")`
        Functions.register(builtins, "parse-time", min_arity: 1, max_arity: 1) { |args| parse_time_input(args.first) }
      end

      # Registers the `format-time` function.
      #
      # @param builtins [Builtins] The Builtins instance.
      def self.register_format_time(builtins)
        # Formats epoch microseconds into a time string: `(format-time (current-time) "%Y-%m-%d")`
        Functions.register(builtins, "format-time", min_arity: 1, max_arity: 2) do |args|
          epoch_usec = args[0]
          format = args[1]
          raise Calc::RuntimeError, "format-time format must be a string" if format && !format.is_a?(String)

          time = from_epoch_usec(epoch_usec)
          format ? time.strftime(format) : time.iso8601(6)
        end
      end

      # Registers month shifting functions (`next-month`, `prev-month`).
      #
      # @param builtins [Builtins] The Builtins instance.
      def self.register_month_shift(builtins)
        # Shifts epoch microseconds by one month forward: `(next-month (current-time))`
        Functions.register(builtins, "next-month", min_arity: 1, max_arity: 1) { |args| shift_month(args.first, 1) }
        # Shifts epoch microseconds by one month backward: `(prev-month (current-time))`
        Functions.register(builtins, "prev-month", min_arity: 1, max_arity: 1) { |args| shift_month(args.first, -1) }
      end

      # Registers month boundary functions (`beggining-of-month`, `end-of-month`).
      #
      # @param builtins [Builtins] The Builtins instance.
      def self.register_month_boundaries(builtins)
        # Returns the start of the month for given epoch microseconds: `(beggining-of-month (current-time))`
        Functions.register(builtins, "beggining-of-month", min_arity: 1, max_arity: 1) do |args|
          time = from_epoch_usec(args.first)
          to_epoch_usec(::Time.utc(time.year, time.month, 1, 0, 0, 0, 0))
        end

        # Returns the end of the month for given epoch microseconds: `(end-of-month (current-time))`
        Functions.register(builtins, "end-of-month", min_arity: 1, max_arity: 1) do |args|
          time = from_epoch_usec(args.first)
          last_day = Date.new(time.year, time.month, -1).day
          to_epoch_usec(::Time.utc(time.year, time.month, last_day, 23, 59, 59, 999_999))
        end
      end

      # Parses a time input string into epoch microseconds.
      #
      # @param input [String] The time string to parse.
      # @return [BigDecimal] The parsed time as epoch microseconds.
      # @raise [Calc::RuntimeError] If the input is not a string or cannot be parsed.
      def self.parse_time_input(input)
        raise Calc::RuntimeError, "parse-time expects a string" unless input.is_a?(String)

        components = Date._parse(input)
        parsed = ::Time.parse(input)
        time = components[:offset].nil? ? utc_time_from_components(components, parsed) : parsed.utc
        to_epoch_usec(time)
      rescue ArgumentError => e
        raise Calc::RuntimeError, e.message
      end

      # Constructs a UTC Time object from parsed date components and a fallback Time object.
      #
      # @param components [Hash] Components parsed by `Date._parse`.
      # @param parsed [Time] A fallback Time object (e.g., from `Time.parse`).
      # @return [Time] The constructed UTC Time object.
      def self.utc_time_from_components(components, parsed)
        year = components[:year] || parsed.year
        month = components[:mon] || parsed.month
        day = components[:mday] || parsed.day
        hour = components[:hour] || parsed.hour
        minute = components[:min] || parsed.min
        second = components[:sec] || parsed.sec
        usec = usec_from_components(components[:sec_fraction], parsed.usec)

        ::Time.utc(year, month, day, hour, minute, second, usec)
      end

      # Extracts microseconds from a fractional second component or falls back to a given microsecond value.
      #
      # @param sec_fraction [BigDecimal, nil] The fractional second component.
      # @param fallback_usec [Integer] The microsecond value to use if `sec_fraction` is nil.
      # @return [Integer] The extracted or fallback microsecond value.
      def self.usec_from_components(sec_fraction, fallback_usec)
        return fallback_usec unless sec_fraction

        (sec_fraction * USEC_PER_SECOND).to_i
      end

      # Shifts a given epoch microsecond time by a specified number of months.
      # Handles month rollovers and adjusts days to fit the target month.
      #
      # @param epoch_usec [BigDecimal] The time in epoch microseconds.
      # @param delta [Integer] The number of months to shift (positive for forward, negative for backward).
      # @return [BigDecimal] The shifted time as epoch microseconds.
      def self.shift_month(epoch_usec, delta)
        time = from_epoch_usec(epoch_usec)
        target_month = time.month + delta
        year_offset, month_index = (target_month - 1).divmod(12)
        year = time.year + year_offset
        month = month_index + 1
        last_day = Date.new(year, month, -1).day
        day = [time.day, last_day].min

        shifted = ::Time.utc(year, month, day, time.hour, time.min, time.sec, time.usec)
        to_epoch_usec(shifted)
      end

      # Converts epoch microseconds to a UTC Time object.
      #
      # @param value [BigDecimal] The time in epoch microseconds.
      # @return [Time] The corresponding UTC Time object.
      def self.from_epoch_usec(value)
        usec_value = normalize_epoch_usec(value)
        seconds, usec = usec_value.divmod(USEC_PER_SECOND)

        ::Time.at(seconds, usec, :microsecond).utc
      end

      # Converts a UTC Time object to epoch microseconds (BigDecimal).
      #
      # @param time [Time] The UTC Time object.
      # @return [BigDecimal] The time as epoch microseconds.
      def self.to_epoch_usec(time)
        BigDecimal(((time.to_i * USEC_PER_SECOND) + time.usec).to_s)
      end

      # Normalizes a value to an integer representing epoch microseconds.
      #
      # @param value [Integer, BigDecimal] The value to normalize.
      # @return [Integer] The normalized epoch microseconds as an integer.
      # @raise [Calc::RuntimeError] If the value is not an integer or BigDecimal with no fractional part.
      def self.normalize_epoch_usec(value)
        case value
        when Integer
          value
        when BigDecimal
          raise Calc::RuntimeError, "time value must be an integer microsecond epoch" unless value.frac.zero?

          value.to_i
        else
          raise Calc::RuntimeError, "time value must be an integer microsecond epoch"
        end
      end
      private_class_method :register_current_time, :register_parse_time, :register_format_time,
                           :register_month_shift, :register_month_boundaries, :parse_time_input,
                           :utc_time_from_components, :usec_from_components,
                           :shift_month, :from_epoch_usec, :to_epoch_usec, :normalize_epoch_usec
    end
  end
end
