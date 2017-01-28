class ShippingFile
  attr_reader :lines

  JANE_TO_STAMPS_SYM = {
    0 => :order_number,
    2 => :full_name,
    3 => :address,
    4 => :address_two,
    5 => :city,
    6 => :state_province,
    7 => :postal_code
  }

  def initialize(jane_csv_file_path)
    @lines = File.readlines(jane_csv_file_path).map(&:chomp).map{|line| line.split(",") }
    @time = Time.now
  end

  def formatted_item(unformatted_item, quantity)
    size, color = unformatted_item.split(";")
    just_color = color.split(":")[1]
    unformatted_size = size.split(" ")[0].split(":")[1]
    just_size = first_letters_size(unformatted_size)
    quantity_and_size = size_with_quantity(just_size, quantity)
    [quantity_and_size, just_color]
  end

  def size_with_quantity(size, quantity)
    quantity.to_i > 1 ? "#{quantity} of #{size}" : "#{size}"
  end

  def first_letters_size(unformatted_size)
    return unformatted_size[0][0] if unformatted_size[0][0].downcase != "x"
    unformatted_size.count("-") > 0 ? with_exes_dash(unformatted_size) : with_exes_no_dash(unformatted_size)
  end

  def with_exes_no_dash(unformatted_size)
    "#{count_exes(unformatted_size)}X#{unformatted_size[-1]}"
  end

  def count_exes(word)
    word = word.downcase
    word.count("x")
  end

  def with_exes_dash(words)
    first, second = words.split("-")
    "#{count_exes(first)}X#{second[0]}"
  end

  def size_and_color(line)
    unformatted_item = line[9]
    formatted_item(unformatted_item, line[11])
  end

  def product_info_to_name
    @lines.map! { |line| name_with_product_info(line) }
  end

  def name_with_product_info(line)
    line[:size].count > 1 ? multiple_sizes(line) : single_size(line)
  end

  def single_size(line)
    name, size, color = line[:full_name], line[:size], line[:color]
    line[:full_name] = "#{name} (#{size[0]} #{color[0]})"
    line
  end

  def multiple_sizes(line)
    name, sizes, colors = line[:full_name], line[:size], line[:color]
    together = merge_sizes_and_colors(sizes, colors)
    line[:full_name] = "#{name} (#{together})"
    line
  end

  def merge_sizes_and_colors(sizes, colors)
    results = []
    sizes.each_with_index {|size, idx| results << "#{size} #{colors[idx]}" }
    results.join(",")
  end

  def stamps_line(line)
    new_hash = empty_stamps_hash
    size, color = size_and_color(line)
    new_hash[:size] << size
    new_hash[:color] << color
    line.each_with_index do |val, idx|
      next if idx >= 9 || idx == 1
      sym = JANE_TO_STAMPS_SYM[idx]
      new_hash[sym] = val
    end
    new_hash
  end

  def sort_by_groups
    @lines.sort_by! { |line| size_color_inverse_order(line) }
  end


# keeping this in the event I want to order things alphabetically in the future

  # def alphabetic_order
  #   @lines.sort_by! { |line| line[:full_name]};
  # end

  def size_color_inverse_order(line)
    [line[:size], line[:color], -line[:order_number].to_i]
  end

  def csv_ready
    @lines.map! { |hash| hash.values.join(",") }
  end

  def empty_stamps_hash
    {
      order_number: nil,
      order_date: "#{@time.month}/#{@time.day}/#{@time.year}",
      order_value: "",
      requested_service: "",
      full_name: nil,
      company: "",
      address: nil,
      address_two: nil,
      address_three:"",
      state_province: nil,
      city: nil,
      postal_code: nil,
      country: "USA",
      phone: "",
      email: "",
      oz: "OZ",
      length: 1,
      width: 1,
      height: 1,
      notes: "",
      more_notes: "",
      gift_wrap: "FALSE",
      gift_message: "",
      size: [],
      color: []
    }
  end

  def stamps_ready_hashes
    @lines.map! { |line| stamps_line(line) }
  end

  def erase_first
    @lines.shift
  end

  def duplicate_orders
    duplicate_order_numbers = []
    order_numbers = just_order_numbers
    @lines.each_with_index do |line, idx|
      order_num = line[:order_number]
      duplicate_order_numbers << order_num if multiple?(order_num, order_numbers)
    end
    duplicate_order_numbers.uniq
  end

  def just_order_numbers
    order_nums = []
    @lines.each {|line| order_nums << line[:order_number] }
    order_nums
  end

  def multiple?(order_num, order_numbers)
    order_numbers.count(order_num) > 1
  end

  def take_care_of_duplicates
    dups = duplicate_orders
    orders_and_indices = duplicate_indices(dups)
    correct_multiples(orders_and_indices)
    @lines = @lines.compact
  end

  def duplicate_indices(duplicate_order_numbers)
    indices = {}
    @lines.each_with_index do |line, idx|
      order_num = line[:order_number]
      if duplicate_order_numbers.include?(order_num)
        if indices.has_key?(order_num)
          indices[order_num] << idx
        else
          indices[order_num] = [idx]
        end
      end
    end
    indices
  end

  def correct_multiples(orders_and_indices)
    orders_and_indices.each {|order_num,indices| replace_multiples(indices) }
  end

  def replace_multiples(indices)
    after_first_indexes = indices.slice(1, indices.count - 1)
    indices.each do |idx|
      if idx == indices.first
        add_names_and_sizes(idx, after_first_indexes)
      else
        @lines[idx] = nil
      end
    end
  end

  def add_names_and_sizes(idx, other_indices)
    other_indices.each do |idx_two|
      @lines[idx][:size] << @lines[idx_two][:size].first
      @lines[idx][:color] << @lines[idx_two][:color].first
    end
  end


end

if __FILE__ == $PROGRAM_NAME
  puts
  puts "What would you like the new file to be called? (Remember to include .csv at the end of the name) "
  puts
  new_file_name = gets.chomp
  puts

  puts "What's the csv file name that you just got from Jane.com? (Remember to include .csv at the end of the name)"
  puts
  file_to_manipulate = gets.chomp

  new_file = ShippingFile.new(file_to_manipulate)

  # Gets rid of old header file/creates stamps ready array of lines.

  new_file.erase_first
  new_file.stamps_ready_hashes
  new_file.take_care_of_duplicates
  new_file.sort_by_groups
  new_file.product_info_to_name
  new_file.csv_ready

  # These are the necessary header names for upload to stamps.com.

  header_row = "Order ID (required),Order Date,Order Value,Requested Service,Ship To - Name,Ship To - Company,Ship To - Address 1,Ship To - Address 2,Ship To - Address 3,Ship To - State/Province,Ship To - City,Ship To - Postal Code,Ship To - Country,Ship To - Phone,Ship To - Email,Total Weight in Oz,Dimensions - Length,Dimensions - Width,Dimensions - Height,Notes - From Customer,Notes - Internal,Gift Wrap?,Gift Message"
  File.open(new_file_name, "w") do |f|
    f.puts header_row
    new_file.lines.each{|line| f.puts line }
  end
end
