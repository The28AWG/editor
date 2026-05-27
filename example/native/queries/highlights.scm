; Копия queries/highlights.scm из tree-sitter-dart (UserNobody14).
; Используется Dart-кодом подсветки после сборки нативных библиотек.
; При обновлении грамматики сверьте с upstream и обновите вручную или: make sync-queries

; Variable
(identifier) @variable

; Keywords
[
 (assert_builtin)
 (break_builtin)
 (const_builtin)
 (part_of_builtin)
 (rethrow_builtin)
 (void_type)
 "abstract"
 "as"
 "async"
 "async*"
 "await"
 "base"
 "case"
 "catch"
 "class"
 "continue"
 "covariant"
 "default"
 "deferred"
 "do"
 "else"
 "enum"
 "export"
 "extends"
 "extension"
 "external"
 "factory"
 "final"
 "finally"
 "for"
 "Function"
 "hide"
 "if"
 "implements"
 "import"
 "in"
 "interface"
 "is"
 "late"
 "library"
 "mixin"
 "new"
 "on"
 "part"
 "required"
 "return"
 "sealed"
 "show"
 "static"
 "super"
 "switch"
 "sync*"
 "throw"
 "try"
 "typedef"
 "var"
 "when"
 "while"
 "with"
 "yield"
] @keyword

(((identifier) @function (#match? @function "^_?[a-z]"))
 . (selector . (argument_part))) @function

(template_substitution
 "$" @punctuation.special
 "{" @punctuation.special
 "}" @punctuation.special
) @none

(template_substitution
 "$" @punctuation.special
 (identifier_dollar_escaped) @variable
) @none

(escape_sequence) @string.escape

[
 "@"
 "=>"
 ".."
 "??"
 "=="
 "?"
 ":"
 "&&"
 "%"
 "<"
 ">"
 "="
 ">="
 "<="
 "||"
 "~/"
 (increment_operator)
 (is_operator)
 (prefix_operator)
 (equality_operator)
 (additive_operator)
] @operator

(type_arguments
 "<" @punctuation.bracket
 ">" @punctuation.bracket)

(type_parameters
 "<" @punctuation.bracket
 ">" @punctuation.bracket)

[
 "("
 ")"
 "["
 "]"
 "{"
 "}"
] @punctuation.bracket

[
 ";"
 "."
 ","
] @punctuation.delimiter

(type_identifier) @type
((type_identifier) @type.builtin
 (#match? @type.builtin "^(int|double|String|bool|List|Set|Map|Runes|Symbol)$"))
(class_definition
 name: (identifier) @type)
(constructor_signature
 name: (identifier) @type)
(scoped_identifier
 scope: (identifier) @type)
(function_signature
 name: (identifier) @function)
(getter_signature
 "get" @keyword
 (identifier) @function)
(setter_signature
 "set" @keyword
 name: (identifier) @function)
(operator_signature
 "operator" @keyword)

((scoped_identifier
 scope: (identifier) @type
 name: (identifier) @type)
 (#match? @type "^[a-zA-Z]"))

(enum_declaration
 name: (identifier) @type)
(enum_constant
 name: (identifier) @identifier.constant)

(inferred_type) @keyword

((identifier) @type
 (#match? @type "^_?[A-Z].*[a-z]"))

("Function" @type)

(this) @variable.builtin

(unconditional_assignable_selector
 (identifier) @property)

(conditional_assignable_selector
 (identifier) @property)

(cascade_section
 (cascade_selector
 (identifier) @property))

((selector
 (unconditional_assignable_selector (identifier) @function))
 (selector (argument_part (arguments)))
)

(cascade_section
 (cascade_selector (identifier) @function)
 (argument_part (arguments))
)

(assignment_expression
 left: (assignable_expression) @variable)

(this) @variable.builtin

(formal_parameter
 name: (identifier) @identifier.parameter)

(named_argument
 (label (identifier) @identifier.parameter))

[
 (hex_integer_literal)
 (decimal_integer_literal)
 (decimal_floating_point_literal)
] @number

(string_literal) @string
(symbol_literal (identifier) @constant) @constant
(true) @boolean
(false) @boolean
(null_literal) @constant.null

(documentation_comment) @comment
(comment) @comment

(annotation
 "@" @attribute
 name: (identifier) @attribute)

(extension_type_declaration
 "type" @keyword)

(extension_type_declaration
 name: (identifier) @type)

(representation_declaration
 name: (identifier) @property)

(switch_expression_case
 "when" @keyword)

(switch_statement_case
 "when" @keyword)

(object_pattern
 (identifier) @property)

(record_pattern
 (identifier) @property)

(record_type_field
 (identifier) @variable)
