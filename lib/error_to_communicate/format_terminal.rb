require 'rouge'

module ErrorToCommunicate
  class FormatTerminal
    def self.call(attributes)
      new(attributes).call
    end

    attr_accessor :cwd, :theme, :heuristic, :format_code, :heuristic_formatter
    def initialize(attributes)
      self.cwd         = attributes.fetch :cwd
      self.theme       = attributes.fetch :theme
      self.heuristic   = attributes.fetch :heuristic
      self.format_code = FormatTerminal::Code.new theme: theme, cwd: cwd # defined below
    end

    # Really, it seems like #format should be #call,
    # which implies that there are two objects in here.
    # One that does the semantic formatting, and one that translates that to text.
    # But I can't quite see it yet, so going to wait until there are more requirements on this.
    def call
      format [
        heuristic.semantic_summary,
        heuristic.semantic_info,
        heuristic.semantic_backtrace,
      ]
    end

    # TODO: not good enough,
    # These need to be able to take things like:
    # [:message, ["a", [:explanation, "b"], "c"]]
    # where "a", and "c", get coloured with the semantics of :message
    def format(semantic_content)
      return semantic_content unless semantic_content.kind_of? Array

      meaning, content, *rest = semantic_content
      case meaning
      when Array        then semantic_content.map { |c| format c }.join
      when :summary     then format([:separator]) + format(content)
      when :heuristic   then format([:separator]) + format(content)
      when :backtrace   then
        if content.any?
          format([:separator]) + format(content)
        else
          format([:separator]) + format([:message, "No backtrace available"]) # TODO: Not tested, I hit this with capybara, when RSpec filtered everything out of the backtrace
        end
      when :separator   then theme.separator_line
      when :columns     then theme.columns     [content, *rest].map { |c| format c }
      when :classname   then theme.classname   format content
      when :message     then theme.message     format content
      when :explanation then theme.explanation format content
      when :context     then theme.context     format content
      when :details     then theme.details     format content
      when :code        then format_code.call  content
      when :null        then ''
      else raise "Wat is #{meaning.inspect}?"
      end
    end


    class Code
      attr_accessor :theme, :cwd

      def initialize(attributes)
        self.theme = attributes.fetch :theme
        self.cwd   = attributes.fetch :cwd
      end

      def call(attributes)
        location       = attributes.fetch :location
        path           = location.path
        line_index     = location.linenum - 1
        highlight      = attributes.fetch :highlight, location.label
        end_index      = bound_num min: 0, num: line_index+attributes.fetch(:context).end
        start_index    = bound_num min: 0, num: line_index+attributes.fetch(:context).begin
        message        = attributes.fetch :message, ''
        message_offset = line_index - start_index
        if attributes.fetch(:mark, true)
          mark_linenum = location.linenum
        else
          mark_linenum = -1
        end

        # first line gives the path
        path_line = [
          theme.color_path("#{path_to_dir cwd, path}/"),
          theme.color_filename(path.basename),
          ":",
          theme.color_linenum(location.linenum),
        ].join("")

        # then display the code
        if path.exist?
          code = File.read(path).lines.to_a[start_index..end_index].join("")
          code = remove_indentation       code
          code = theme.syntax_highlight   code
          code = prefix_linenos_to        code, start_index.next, mark: mark_linenum
          code = add_message_to           code, message_offset, theme.screaming_red(message)
          code = theme.highlight_text     code, message_offset, highlight
        else
          code = "Can't find code\n"
        end

        # adjust for emphasization
        if attributes.fetch(:emphasis) == :path
          path_line = theme.underline      path_line
          code      = theme.indent         code, "      "
          code      = theme.desaturate     code
          code      = theme.highlight_text code, message_offset, highlight # b/c desaturate really strips color
        end

        # all together
        path_line << "\n" << code
      end

      def path_to_dir(from, to)
        to.expand_path.relative_path_from(from).dirname
      rescue ArgumentError
        return to # eg rbx's core code
      end

      def bound_num(attributes)
        num = attributes.fetch :num
        min = attributes.fetch :min
        num < min ? min : num
      end

      def remove_indentation(code)
        indentation = code.scan(/^[ \r\t]*/).min_by(&:length)
        code.gsub(/^#{indentation}/, "")
      end

      def prefix_linenos_to(code, start_linenum, options)
        line_to_mark  = options.fetch :mark
        lines         = code.lines.to_a
        max_linenum   = lines.length + start_linenum - 1 # 1 to translate to indexes
        linenum_width = max_linenum.to_s.length + 4     # 1 for the colon, 3 for the arrow/space
        lines.zip(start_linenum..max_linenum)
             .map { |line, num|
               if line_to_mark == num
                 formatted_num = "-> #{num}:".ljust(linenum_width)
                 formatted_num = theme.mark_linenum formatted_num
               else
                 formatted_num = "   #{num}:".ljust(linenum_width)
               end
               theme.color_linenum(formatted_num) << " " << line
             }.join("")
      end

      def add_message_to(code, offset, message)
        lines = code.lines.to_a
        lines[offset].chomp! << " " << message << "\n"
        lines.join("")
      end
    end
  end
end
