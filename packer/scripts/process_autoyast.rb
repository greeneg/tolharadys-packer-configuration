#!/usr/bin/env ruby

require 'erb'
require 'getoptlong'
require 'json'

class XmlTemplate
  attr_accessor :root_passwd_hash

  def initialize(root_passwd_hash)
    @root_passwd_hash = root_passwd_hash
  end

  def get_binding
    binding()
  end
end

# read in the JSON file
def read_json j_file
  data = nil
  open(j_file) do |f|
    data = f.read
  end
  j = JSON.parse(data)

  return j
end

def read_template t_file
  data = nil
  open(t_file) do |f|
    data = f.read
  end

  return data
end

NAME    = 'process_autoyast'
VERSION = '0.0.1'

opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--version', '-v', GetoptLong::NO_ARGUMENT ],
  [ '--template', '-t', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--json', '-j', GetoptLong::REQUIRED_ARGUMENT ]
)

t_file = nil
j_file = nil

opts.each do |opt, arg|
  case opt
    when '--help'
      puts <<-EOF
process_variable_file.rb [OPTIONS]

  -h, --help
    Show this help output

  -v, --version
    Show the version of this script

  -t, --template [AUTOYAST TEMPLATE FILE]
    The template file to process

  -j, --json [JSON TEMPLATE FILE]
    The JSON file to read values from
      EOF
      exit
    when '--version'
      puts "#{NAME}: v#{VERSION}"
      exit
    when '--template'
      t_file = arg
    when '--json'
      j_file = arg
  end
end

j_obj = read_json j_file
value = j_obj['root_passwd_hash']
template = read_template t_file

root_passwd_hash = XmlTemplate.new(value)
renderer = ERB.new(template)
puts output = renderer.result(root_passwd_hash.get_binding)
