require 'rubygems'
require 'doc_raptor'
require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../utilities/oraclequery.rb'

# Local path var(s)
pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "bookmaker_pdfmaker")

project_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").shift
stage_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").pop

# Authentication data is required to use docraptor and 
# to post images and other assets to the ftp for inclusion 
# via docraptor. This auth data should be housed in 
# separate files, as laid out in the following block.
docraptor_key = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/api_key.txt")
ftp_uname = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_username.txt")
ftp_pass = File.read("#{Bkmkr::Paths.scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
ftp_dir = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg"
coverdir = Bkmkr::Paths.submitted_images
template_html = File.join(Bkmkr::Paths.project_tmp_dir, "titlepage.html")
pdf_css_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css")
gettitlepagejs = File.join(Bkmkr::Paths.scripts_dir, "covermaker", "scripts", "generic", "get_titlepage.js")
cover_pdf = File.join(coverdir, "titlepage.pdf")
final_cover = File.join(coverdir, "titlepage.jpg")

# testing to see if ISBN style exists
spanisbn = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn/)
multiple_isbns = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand)|(e\s*-*\s*book))\)/)

# determining print isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
  pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand))\)/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  pisbn = pisbn_basestring.match(/\d+\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.?on.?demand))\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
  pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  pisbn = pisbn_basestring.match(/\d+/).to_s.gsub(/\["/,"").gsub(/"\]/,"")
else
  pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/ISBN\s*.+\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand))\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  pisbn = pisbn_basestring.match(/\d+\(.*\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# determining ebook isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
  eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/<span class="spanISBNisbn">\s*.+<\/span>\s*\(e\s*-*\s*book\)/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  eisbn = eisbn_basestring.match(/\d+\(ebook\)/).to_s.gsub(/\(ebook\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
  eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  eisbn = pisbn_basestring.match(/\d+/).to_s.gsub(/\["/,"").gsub(/"\]/,"")
else
  eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/ISBN\s*.+\s*\(e-*book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
  eisbn = eisbn_basestring.match(/\d+\(ebook\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# just in case no isbn is found
if pisbn.length == 0 and eisbn.length != 0
  pisbn = eisbn
elsif pisbn.length == 0 and eisbn.length == 0
  pisbn = Bkmkr::Project.filename
end

if pisbn.length == 0 and eisbn.length != 0
  pisbn = eisbn
elsif pisbn.length != 0 and eisbn.length == 0
  eisbn = pisbn
elsif pisbn.length == 0 and eisbn.length == 0
  pisbn = Bkmkr::Project.filename
  eisbn = Bkmkr::Project.filename
end

# must go after the isbn finder
arch_cover = File.join(Bkmkr::Paths.done_dir, pisbn, "images", "titlepage.jpg")

# pdf css to be added to the file that will be sent to docraptor
# pdf css to be added to the file that will be sent to docraptor
if File.file?("#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/titlepage.css")
  cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/#{project_dir}/titlepage.css"
else
  cover_css_file = "#{Bkmkr::Paths.scripts_dir}/covermaker/css/generic/titlepage.css"
end

embedcss = File.read(cover_css_file).gsub(/(\\)/,"\\0\\0").to_s

# do content conversions
Bkmkr::Tools.runnode(gettitlepagejs, "#{Bkmkr::Paths.outputtmp_html} #{template_html}")

pdf_html = File.read(template_html).gsub(/<\/head>/,"<style>#{embedcss}</style></head>").to_s

# Docraptor setup
DocRaptor.api_key "#{Bkmkr::Keys.docraptor_key}"

# change to DocRaptor 'test' mode when running from staging server
testing_value = "false"
if File.file?("#{Bkmkr::Paths.resource_dir}/staging.txt") then testing_value = "true" end

# sends file to docraptor for conversion
unless File.file?(final_cover) or File.file?(arch_cover)
  FileUtils.cd(coverdir)
  File.open(cover_pdf, "w+b") do |f|
    f.write DocRaptor.create(:document_content => pdf_html,
                             :name             => "titlepage.pdf",
                             :document_type    => "pdf",
                             :strict			     => "none",
                             :test             => "#{testing_value}",
  	                         :prince_options	 => {
  	                           :http_user		 => "#{Bkmkr::Keys.http_username}",
  	                           :http_password	 => "#{Bkmkr::Keys.http_password}",
                                 :javascript       => "true"
  							             }
                         		)                         
  end
  # convert to jpg
  `convert -density 150 "#{cover_pdf}" -quality 100 -sharpen 0x1.0 -resize 600 "#{final_cover}"`

  #FileUtils.rm(cover_pdf)
end

# TESTING
if File.file?(final_cover)
  test_jpg_status = "pass: I found a titlepage image"
else
  test_jpg_status = "FAIL: no titlepage image was created"
end

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
  f.puts "----- TITLEPAGE PROCESSES"
  f.puts test_jpg_status
end