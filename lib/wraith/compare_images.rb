require 'wraith'
require 'image_size'
require 'open3'

class Wraith::CompareImages
  attr_reader :wraith

  def initialize(config)
    @wraith = Wraith::Wraith.new(config)
  end

  def compare_images
    files = Dir.glob("#{wraith.directory}/*/*.png").sort

    until files.empty?
      base, files = @wraith.get_files_from_array_while_regex(files,@wraith.base_domain_label,@wraith.comp_domain_label)
      compare, files = @wraith.get_files_from_array_while_regex(files,@wraith.comp_domain_label,@wraith.base_domain_label)
      #in fact should only be base file at a time
      base.each do |base_file|
        base_width = @wraith.find_image_dimensions(base_file,'width')
        #can be multiple compare files if using browser based comparison
        compare.each do |compare_file|
          compare_width = @wraith.find_image_dimensions(compare_file,'width')
          #if base and compare images have different widths then can not be diffed
          #for some reason selenium quite buggy with resizing browser windows correctly
          diff_file = compare_file.gsub(/([a-z0-9]+).png$/, 'diff.png')
          info_file = compare_file.gsub(/([a-z0-9]+).png$/, 'data.txt')
          if base_width != compare_width
            #copy over invalid files for display in gallery
            FileUtils.cp('assets/invalid.jpg',diff_file)
            FileUtils.cp('assets/invalid.txt',info_file)
            next
          end

          begin
            compare_task(base_file, compare_file, diff_file, info_file)
            Dir.glob("#{wraith.directory}/*/*.txt").map { |f| "\n#{f}\n#{File.read(f)}" }
            puts 'Saved diff'
          end
        end
      end
    end
  end

  def percentage(img_size, px_value, info)
    pixel_count = (px_value / img_size) * 100
    rounded = pixel_count.round(2)
    File.open(info, 'w') { |file| file.write(rounded) }
  end

  def compare_task(base, compare, output, info)
    cmdline = "compare -fuzz #{wraith.fuzz} -metric AE -highlight-color blue #{base} #{compare} #{output}"
    px_value = Open3.popen3(cmdline) { |stdin, stdout, stderr, wait_thr| stderr.read }.to_f
    img_size = ImageSize.path(output).size.inject(:*)
    percentage(img_size, px_value, info)
  end
end
