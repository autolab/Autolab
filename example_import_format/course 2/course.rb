#
# course.rb - Autolab Course Configuration File
#
# This file is cached on the Autolab server.
#
# To make your changes go live: Admin->Reload course config file
# Alternatively: Admin->Course Settings->Upload Course.rb
#
# To check for typos before reloading in Autolab:
# linux> irb
# irb> load 'course.rb'
# irb> quit
#

#
# 1. Assessment category averages - The first set of functions control
# how the student's average score for each assessment category is
# computed. For each assessment category "foo", you'll need to define
# a function called fooAverage(). For example, if there is an
# assessment category called "Lab", then you define a function called
# LabAverage()
#
# The scores for each assessment are available as user['bar'].to_f(),
# where bar is the name of the assessment. For example, if you had two
# assignments called "datalab" and "bomblab" in the "Lab" category, you
# might say:
#
#    def LabAverage(user)
#        return ((user['datalab'].to_f() + user['bomblab'].to_f())
#        / (64+70)) * 100.0
#    end
#

#
# fooAverage - Computes the gradebook average for category "foo"
#
def fooAverage(_user)
  0
end

#
# 2. courseAverage - This function computes a course average as a
# function of the averages of each of the assessment categories.  The
# average for category foo (computed by fooAverage() above) is available
# as user['catfoo'].to_f(). For example, if you've defined assessment
# categories "Lab" and "Exam", then an example courseAverage() function
# might be:
#
# def courseAverage(user)
#     return (user['catLab'].to_f())*0.4 + user['catExam'].to_f())*0.6
# end
#
def courseAverage(_user)
  0
end
