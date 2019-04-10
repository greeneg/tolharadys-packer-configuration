#!/usr/bin/env ruby

require 'erb'
require 'getoptlong'
require 'json'

is_error = false

class PackerTemplate
  attr_accessor :file_name
  attr_accessor :ssh_password

  def initialize(file_name, ssh_password)
    @file_name = file_name
    @ssh_password = ssh_password
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

def write_json j_data, j_file
  f = File.open(j_file, "w+")
  f.puts j_data
  f.close
end

def read_template t_file
  data = nil
  open(t_file) do |f|
    data = f.read
  end

  return data
end

def usage is_error
  STDERR.puts <<-EOF
process_variable_file.rb [OPTIONS]

  -h, --help
    Show this help output

  -v, --version
    Show the version of this script

  -t, --template [PACKER TEMPLATE FILE]
    The template file to process

  -j, --json [JSON TEMPLATE FILE]
    The JSON file to read values from

  -f, --version-file [IMAGE VERSION FILE]
    The last build's semver file for the image

  --patch
    Specifies that this build is a patch version change

  --minor
    Specifies that this build is a minor version change

  --major
    Specifies that this build is a major version change
  EOF

  if is_error == true
    exit -1
  else
    exit 0
  end
end

NAME    = 'process_variables'
VERSION = '0.0.2'

opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--version', '-v', GetoptLong::NO_ARGUMENT ],
  [ '--template', '-t', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--secrets-json', '-s', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--metadata-json', '-j', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--version-file', '-f', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--patch', GetoptLong::NO_ARGUMENT ],
  [ '--minor', GetoptLong::NO_ARGUMENT ],
  [ '--major', GetoptLong::NO_ARGUMENT ],
  [ '--debug', GetoptLong::NO_ARGUMENT ],
  [ '--no-commit', GetoptLong::NO_ARGUMENT ]
)

# turn off stack tracing
opts.quiet = true

t_file = nil
j_file = nil
s_file = nil
v_file = nil
p_ver = false
min_ver = false
maj_ver = false
with_debug = false
commit = true

opts.each do |opt, arg|
  case opt
    when '--help'
      usage false
    when '--version'
      puts "#{NAME}: v#{VERSION}"
      exit
    when '--template'
      t_file = arg
    when '--secrets-json'
      s_file = arg
    when '--metadata-json'
      j_file = arg
    when '--version-file'
      v_file = arg
    when '--patch'
      p_ver = true
    when '--minor'
      min_ver = true
    when '--major'
      maj_ver = true
    when '--debug'
      with_debug = true
    when '--no-commit'
      commit = false
  end
end

# if any of these are nil, we didn't get appropriate flags to continue
if t_file.nil?
  puts "Template file must be defined!\n"
  usage true
end
if j_file.nil?
  puts "Values file must be defined!\n"
  usage true
end
if s_file.nil?
  puts "Secrets file must be defined!\n"
  usage true
end
if v_file.nil?
  puts "Version file must be defined!\n"
  usage true
end

if p_ver != true
  if min_ver != true
    if maj_ver != true
      usage true
    end
  end
end

ver_info = read_json v_file
if p_ver == true
  # read in the current patch version and then increment
  p_num = ver_info['patch_number'] + 1
  ver_info['patch_number'] = p_num
else
  p_num = ver_info['patch_number']
end
STDERR.puts "Patch Number: #{p_num}" if with_debug == true
if min_ver == true
  min_num = ver_info['minor_number'] + 1
  ver_info['minor_number'] = min_num
else
  min_num = ver_info['minor_number']
end
STDERR.puts "Minor Number: #{min_num}" if with_debug == true
if maj_ver == true
  maj_num = ver_info['major_number'] + 1
  ver_info['major_number'] = maj_num
else
  maj_num = ver_info['major_number']
end
STDERR.puts "Major Number: #{maj_num}" if with_debug == true
semver = "v#{maj_num}.#{min_num}.#{p_num}"
STDERR.puts "Image version: #{semver}" if with_debug == true
write_json JSON.dump(ver_info), v_file if commit == true

s_obj = read_json s_file
j_obj = read_json j_file
os_name = j_obj['os_name']
os_version = j_obj['os_version']
os_architecture = j_obj['os_architecture']
ssh_passwd = s_obj['ssh_passwd']
template = read_template t_file

# create the full file name
file_name = "#{os_name}-#{os_version}-#{os_architecture}-#{semver}.qcow2"

STDERR.puts "Tamplate to write: #{file_name}" if with_debug == true

template_obj = PackerTemplate.new(file_name, ssh_passwd)
renderer = ERB.new(template)
puts output = renderer.result(template_obj.get_binding)
