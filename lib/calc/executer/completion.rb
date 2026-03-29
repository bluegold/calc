module Calc
  class Executer
    # Module providing logic for generating auto-completion candidates,
    # used in interactive environments like the REPL.
    # It collects special forms, built-in functions, variables, and identifiers
    # from the current namespace based on the current context.
    module Completion
      # Generates a list of auto-completion candidates based on the current context.
      #
      # @param namespace_path [String, nil] The current namespace path for completion.
      # @return [Array<String>] A sorted list of completion candidates.
      def completion_candidates(namespace_path: nil)
        (
          SPECIAL_FORMS +
          @builtins.each_builtin.map(&:name) +
          Builtins::LITERALS.keys +
          @environment.binding_names +
          @namespaces.accessible_unqualified_identifiers(namespace_path) +
          @namespaces.function_identifiers +
          @namespaces.variable_identifiers
        ).uniq.sort
      end
    end
  end
end
