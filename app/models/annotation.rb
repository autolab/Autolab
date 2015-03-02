class Annotation < ActiveRecord::Base
  belongs_to :submission
  belongs_to :problem

  validates_presence_of :submission_id, :filename
  validates_presence_of :line, :comment

  def self.NO_PROBLEM
    "_"
  end

  def self.SYNTAX_ERROR
    "!"
  end

  def self.PLAIN_ANNOTATION
    "~"
  end

  def self.PARSE_ERROR_MESSAGE
    "Invalid Syntax"
  end

  def self.INVALID_PROBLEM
    "?"
  end

  def self.INVALID_VALUE
    "?"
  end

  def self.GRADE_SEPARATOR
    ";"
  end

  def self.VALUE_PROBLEM_SEPARATOR
    ":"
  end

  def self.plus_fix(f)
    f.to_f > 0 ? "+#{f}" : "#{f}"
  end

  # different annotations are separated by GRADE_SEPARATOR
  def self.extract_grades(text)
    return text.split(self.GRADE_SEPARATOR)
  end

  # description is everything up to the first '['
  def self.extract_description(tag)
    return tag[0...tag.index("[")].strip
  end

  # something has a grade if it has '[' and ']' 
  # and '[' is before ']'
  def self.has_grade?(text)
    left = text.index('[')
    right = text.index(']')
    return left && right && (left < right)
  end

  def self.has_error?(text)
    inComment = false
    for c in text.each_char do
      if c == "[" then inComment = true
      elsif c == "]" then inComment = false
      elsif c == "?" and inComment then return true
      end
    end
    return false
  end

  # first try to extract the value and the problem
  # if there weren't enough 'arguments' [2] or there
  # were too many 'arguments' [2:wahoo:hello] then
  # it is a syntax error. This is signaled by returning
  # self.SYNTAX_ERROR for the problem
  #
  # additionally, if the value is not parseable with .to_f,
  # then set value to INVALID_VALUE
  def self.extract_value_and_problem(tag)
    vp = /(?<=\[).*?(?=\])/.match(tag).to_s.split(self.VALUE_PROBLEM_SEPARATOR)
    # vp stands for [value,problem]

    case vp.length
    when 0 
      return [0.0, self.NO_PROBLEM] # return [0.0, self.SYNTAX_ERROR]
    when 1 # just a score, belongs to no problem
      vp = vp + [self.NO_PROBLEM] #vp = vp + [self.SYNTAX_ERROR]
    when 2
      # do nothing
    else
      vp =  [vp[0], self.SYNTAX_ERROR]
    end

    if vp[0] == "" then vp[0] = "0" end
    # error if it doesn't convert to float properly
    if vp[0].to_f == 0.0 && vp[0].strip[0] != "0" then
      vp[0] = self.INVALID_VALUE
    else
      vp[0] = vp[0].to_f
    end
    return vp
  end

  # use all the helpers to get a list of [description, value, line, problem]
  # this typically will be only one tuple, but an annotation
  # can have more than one comment in it. The number of tuples in the list
  # is equal to the number of comments in the annotation
  def self.scrape_text(text, line, submission_id=nil)
    separate_grades = self.extract_grades(text)

    tuples = []
    for grade in separate_grades do
      if self.has_grade?(grade) then
        description = self.extract_description(grade)
        value, problem = self.extract_value_and_problem(grade)
        tuple = [description, value, line, problem]
        tuples << tuple
      else # no grades, just return the description
        description = grade
        problem = self.PLAIN_ANNOTATION
        tuple = [description, nil, nil, problem]
        tuples << tuple
      end
    end
    return tuples
  end

  # depending on the format of the input, redirect the information
  # to different functions that will contruct the message returned
  def self.parse_input(text, lineNum, problems)
    parsed_text = ""
    for description, value, line, problem in self.scrape_text(text, lineNum) do
      case problem
      when self.PLAIN_ANNOTATION then
        parsed_text += description 
      when self.NO_PROBLEM then
        parsed_text += self.construct_NO_PROBLEM(description, value)
      when self.SYNTAX_ERROR then
        parsed_text += self.construct_SYNTAX_ERROR(description, value)
      when self.INVALID_PROBLEM then
        parsed_text += self.construct_INVALID_PROBLEM(description, value)
      else # properly formatted
        problem = self.find_problem(problem, problems)
        parsed_text += self.construct_annotation(description, value, problem)
      end 
      parsed_text += self.GRADE_SEPARATOR + " "
    end
    return parsed_text[0...(parsed_text.length - 2)] # don't include last semicolon
  end

  def self.construct_NO_PROBLEM(description, value)
    return "#{description} [#{self.plus_fix(value)}]"
  end

  def self.construct_SYNTAX_ERROR(description, value)
    return "#{description} [?]"
  end

  def self.construct_INVALID_PROBLEM(description, value)
    return "#{description} [#{self.plus_fix(value)}:#{self.INVALID_PROBLEM}]"
  end

  def self.construct_annotation(description, value, problem)
    return "#{description} [#{self.plus_fix(value)}:#{problem}]"
  end

  # this function finds the problem either
  # this can either be a shortcut (#1)
  # or the whole name.
  # the problems are matched by putting them in lowercase
  # and taking out spaces to make it easier to match
  def self.find_problem(problem, problems)
    shortcut = /#(\d*)/.match(problem)
    if shortcut then
      index = shortcut[1].to_i - 1
      if (0 <= index) && (index < problems.length) then
        return problems[index]
      end
    end
    for p in problems do
      if p.downcase.gsub(' ', '') == problem.downcase.gsub(' ', '') then
        return p
      end
    end
    return self.INVALID_PROBLEM
  end

  def as_text
    if (self.value) then
      if (self.problem) then
        "#{self.comment} (#{self.value}, #{self.problem.name})"
      else
        "#{self.comment} (#{self.value})"
      end
    elsif (self.problem) then
      "#{self.comment} (#{self.problem.name})"
    else
      self.comment
    end
  end

  # instance method that just calls the class method
  def has_grades?
    for grade in Annotation.extract_grades(self.text) do
      if Annotation.has_grade?(grade) then
        return true
      end
    end
    return false
  end

  def get_grades
    return Annotation.scrape_text(self.text, self.line)
  end

  # ========================================================
  # The following accessors lazily upgrade annotations to v2
  # of the Annotations model with separate comment, value
  # and problem attributes.
  # ========================================================

  def comment
    upgrade_to_v2 
    return read_attribute(:comment)
  end

  def value 
    upgrade_to_v2
    return read_attribute(:value)
  end

  # since "problem" is a Rails association, we alias it first
  # to "problem_association" so we can access it in our shadow method
  # "problem" that performs the v2 upgrade
  alias_method :problem_association, :problem
  def problem
    upgrade_to_v2
    return problem_association
  end

  def problem_id
    upgrade_to_v2
    return read_attribute(:problem_id)
  end

  def upgrade_to_v2
    #comment_value_problem = parse_text_to_attributes
    #update_attributes(comment_value_problem)
  end

  # Annotations v1 parser
  #
  # Examples:
  #   blah => ('blah', nil, nil)
  #   blah [+4.0] => ('blah', 4.0, nil)
  #   blah [-4.0] => ('blah', -4.0, nil)
  #   blah [+4.0:problem_name] => ('blah', +4.0, <Problem>)     # where <Problem> is a Problem object
  #   blah [blah] => ('blah [blah]', nil, nil)
  #   blah [blah:blah] => ('blah [blah:blah]', nil, nil)
  #   blah [+4.0:bad] => ('blah', +4.0, nil)                    # where bad is NOT a valid problem_name
  def parse_text_to_attributes
    # return text as comment, by default
    result = { "comment" => self.text, "problem_id" => nil, "value" => nil }
  
    # process the "[+4.0:problem_name]" part
    def parse_value_problem(s_p)
        value_problem = {}
    
        # parse value and problem name
        s_p = s_p[1...-1]         # remove starting and trailing brackets
        s_p = s_p.split(":", 2)   # split on :, at most two parts
        value_text = s_p[0]
        problem_name = s_p[1]     # if no : to split on, problem_name is nil
        
        # extract value, return nil if unable to
        value = Float(value_text) rescue nil 
        value_problem.update({ "value" => value }) if value

        # extract problem, ignore problem if problem_name is invalid or not provided
        if problem_name and (problem = self.submission.assessment.problems.find_by_name(problem_name))
          value_problem.update({ "problem_id" => problem.id })
        end

        return value_problem
    end
  
    # if there is a right bracket (]) at the end
    if self.text.end_with?("]") then
      
      # and a left bracket ([) (find the last one)
      if (l_bracket = self.text.rindex("["))

        # extract value and problem from string between brackets (incl. brackets)
        value_problem = parse_value_problem(self.text[l_bracket..-1])
        result.update(value_problem)

        # extract comment
        comment = self.text[0...l_bracket].rstrip
        result.update({ "comment" => comment })
      end 
    end
      
    return result 
  end
end
