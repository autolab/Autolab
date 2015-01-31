# Production
require 'net/http'
require 'json'
require 'pathname'
require_relative "../ModuleBase.rb"
require_relative "../autoConfig.rb"
require "digest/md5"


#include ModuleBase

# The Autograde module overrides the handin action and provides the
# 'autogradeDone' action which is called by Tango on completion of a job to
# notify Autolab 
module Autograde
  include ModuleBase
end

