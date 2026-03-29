module Calc
  class Executer
    module Completion
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
