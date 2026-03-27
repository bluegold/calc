require "bigdecimal"
require "date"
require "time"

module Calc
  module Functions
    module Time
      USEC_PER_SECOND = 1_000_000

      def self.register(builtins)
        register_current_time(builtins)
        register_parse_time(builtins)
        register_format_time(builtins)
        register_month_shift(builtins)
        register_month_boundaries(builtins)
      end

      def self.register_current_time(builtins)
        Functions.register(builtins, "current-time", min_arity: 0, max_arity: 0) { |_args| to_epoch_usec(::Time.now.utc) }
      end

      def self.register_parse_time(builtins)
        Functions.register(builtins, "parse-time", min_arity: 1, max_arity: 1) { |args| parse_time_input(args.first) }
      end

      def self.register_format_time(builtins)
        Functions.register(builtins, "format-time", min_arity: 1, max_arity: 2) do |args|
          epoch_usec = args[0]
          format = args[1]
          raise Calc::RuntimeError, "format-time format must be a string" if format && !format.is_a?(String)

          time = from_epoch_usec(epoch_usec)
          format ? time.strftime(format) : time.iso8601(6)
        end
      end

      def self.register_month_shift(builtins)
        Functions.register(builtins, "next-month", min_arity: 1, max_arity: 1) { |args| shift_month(args.first, 1) }
        Functions.register(builtins, "prev-month", min_arity: 1, max_arity: 1) { |args| shift_month(args.first, -1) }
      end

      def self.register_month_boundaries(builtins)
        Functions.register(builtins, "beggining-of-month", min_arity: 1, max_arity: 1) do |args|
          time = from_epoch_usec(args.first)
          to_epoch_usec(::Time.utc(time.year, time.month, 1, 0, 0, 0, 0))
        end

        Functions.register(builtins, "end-of-month", min_arity: 1, max_arity: 1) do |args|
          time = from_epoch_usec(args.first)
          last_day = Date.new(time.year, time.month, -1).day
          to_epoch_usec(::Time.utc(time.year, time.month, last_day, 23, 59, 59, 999_999))
        end
      end

      def self.parse_time_input(input)
        raise Calc::RuntimeError, "parse-time expects a string" unless input.is_a?(String)

        components = Date._parse(input)
        parsed = ::Time.parse(input)
        time = components[:offset].nil? ? utc_time_from_components(components, parsed) : parsed.utc
        to_epoch_usec(time)
      rescue ArgumentError => e
        raise Calc::RuntimeError, e.message
      end

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

      def self.usec_from_components(sec_fraction, fallback_usec)
        return fallback_usec unless sec_fraction

        (sec_fraction * USEC_PER_SECOND).to_i
      end

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

      def self.from_epoch_usec(value)
        usec_value = normalize_epoch_usec(value)
        seconds, usec = usec_value.divmod(USEC_PER_SECOND)

        ::Time.at(seconds, usec, :microsecond).utc
      end

      def self.to_epoch_usec(time)
        BigDecimal(((time.to_i * USEC_PER_SECOND) + time.usec).to_s)
      end

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
