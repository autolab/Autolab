#
# course.rb - Autolab Course Configuration File
# v 2.0
#
# This file is cached on the Autolab server.
#
# To make your changes go live: Admin->Reload course config file
#
# To check for typos before reloading in Autolab:
# linux> irb
# irb> load 'course.rb'
# irb> quit
#

#
# 1. Assessment category scores - The first set of functions control
# how the student's score is aggregated for each assessment category.
# For each assessment category "Foo", you'll need to define
# a function called FooAggregate(). For example, if there is an
# assessment category called "Lab", then you define a function called
# LabAggregate()
#
# The function should return a dictionary with two keys:
#  :name (string value indicating the display name of the aggregate)
#  :value (the value of the aggregate)
#
# The scores for each assessment are available as user['bar'].to_f(),
# where bar is the name of the assessment. For example, if you had two
# assignments called "datalab" and "bomblab" in the "Lab" category, you
# might say:
#
#    def LabAggregate(user)
#        return { name: "Average",
#                 value: ((user['datalab'].to_f() + user['bomblab'].to_f())
#                            / (64+70)) * 100.0 }
#    end
#
#
# If you don't want a category aggregate, you can indicate return the
# dictionary { name: nil, value: nil } which will provide no
# scores and will not appear in the gradebook table

#
# FooAggregate - Computes the gradebook average for category "foo"
#
def FooAggregate(user)
  {}
end

#
# 2. courseAggregate - This function computes a course Aggregate as a
# function of the assessment scores and category aggregates. For example,
# average for category foo (computed by FooAverage() above) is available
# as user_cats['Foo'].to_f(). For example, if you've defined assessment
# categories "Lab" and "Exam", then an example courseAverage() function
# might be:
#
# def courseAggregate(user_assmts, user_cats)
#     return {name: "Weighted Score",
#             value: (user_cats['Lab'].to_f())*0.4 + user_cats['Exam'].to_f())*0.6}
# end
#
# Note that there is no way to avoid having a course aggregate, a nil value will
# cause an error
#
def courseAggregate(user_assmts, user_cats)
     return {name: "Category Total",
	     value: 100 }
end

#
# 3. gradebookMessage - Displays a message on the student gradebook
#
def gradebookMessage
  " "
end
