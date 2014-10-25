module AnnotationHelper
  def line_class(annotation)
    annotation ? '"annotated line"' : '"line"'
  end

  def annotation_mod_class(annotation)
    annotation ? '"annotationModifier deleteAnnotation"' : '"annotationModifier createAnnotation"'
  end

  def annotation_mod(annotation)
    annotation ? '&#215;' : '+'
  end

  def annotation_class(annotation)
    if annotation then
      text = '"annotation updateAnnotation'
      if Annotation.has_error?(annotation.text) then
        text += ' syntaxError"'
      else
        text += '"'
      end
    else
      text = '"annotation createAnnotation"'
    end
  end

  def annotation_id(annotation)
    annotation ? '"annotation' + annotation.id.to_s + '"' : '""'
  end

  def annotation_text(annotation)
    annotation_raw_text(annotation).gsub("\u0001", "[").gsub("\u0002", "]")
  end

  def annotation_raw_text(annotation)
    if annotation
      annotation.text
    elsif @cud.instructor? || @cud.course_assistant?
      "Add Annotation"
    else
      ""
    end
  end

  def plus_fix(f)
    f > 0 ? "+#{f}" : "#{f}"
  end
end
