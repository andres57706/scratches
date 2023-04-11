require 'rubyXL'
require 'pry'

# Implementation of String class adds
# methods to be used by this script
class String
  # Map any input key to the desired output
  MAPPING_KEYS = {
    cedula_identidad: 'rut',
    devengos_prestacionales: 'total_haberes_imponibles',
    devengos_no_prestacionales: 'total_haberes_no_imponibles',
    otros_descuentos: 'total_otros_descuentos',
    descuentos_legales: 'total_descuentos_legales',
    total_neto: 'liquido',
    neto_a_pagar: 'liquido'
  }.freeze

  # Transforms a string aplying some rules for special characters
  #
  # @param text [String] string to be transformed
  # @return [String] A transformed text
  def special_characters
    tr('áéíóú', 'aeiou') # accent rule for vocals
      .tr(' ', '_') # whitespace transformation
  end

  # Maps a key from input to a desired value using
  # the MAPPING_KEYS constant Hash
  #
  # @param key [String] A key to be mapped
  # @return [String] Mapped key to it's new name
  def map_keys
    MAPPING_KEYS[to_sym] || self
  end
end

#
# Own implementation of Hash class
# with transformation types method
class Hash
  # Holds the transformation for
  # the desired result keys
  KEY_VALUE_TYPE_TRANSFORMER = {
    rut: proc { |value| value.to_s },
    code: proc { |value| value.to_s },
    monto: proc { |value| value.to_i }
  }.freeze

  # Transform a hash using the KEY_VALUE_TYPE_TRANSFORMER constant
  # useful to transform every desired key to an output
  def transform_values_types
    result = self

    result.each do |k, v|
      if KEY_VALUE_TYPE_TRANSFORMER.key?(k)
        result[k] = KEY_VALUE_TYPE_TRANSFORMER[k.to_sym].call result[k]
      elsif v.is_a? Hash
        v.transform_values_types
      elsif v.is_a? Array
        v.select { |item| item.is_a? Hash }.each(&:transform_values_types)
      end
    end
  end
end

# Imports an xlsx file with a single sheet and returns an array of hashes.
# The first row of the sheet is considered as headers, and each row is
# converted into a hash where the keys are the header values and the values
# are the corresponding cell values.
#
# @param file_path [String] The path to the xlsx file.
# @return [Array<Hash>] An array of hashes representing each row in the sheet.
#   The keys are the header values and the values are the corresponding cell values.
def import_xlsx(file_path)
  workbook = RubyXL::Parser.parse(file_path)
  sheet = workbook[0]
  headers = sheet[0].cells.map { |r| r.value.downcase }

  rows = sheet.drop(1).compact

  rows.each_with_object([]) do |row, arr|
    r = headers.zip(row.cells.filter_map { |rw| rw&.value }).to_h
    arr << r if r.all? { |_, v| !v.nil? }
  end
end

# Transforms an hash by pushing specified keys into a new hash with an 'items' key.
#
# @param hash [Hash]  Hash to transform
# @param keys [Array<String>] The keys to push into a new hash with an 'items' key.
# @return [Hash] A transformed hash.
def transform_hash(hash, keys)
  # set a new hash removing desired key values
  new_hash = hash.reject { |k, _| keys.include?(k) }

  if keys.any?
    # Transform desired keys to an array of hashes [{code: 'key', monto: 'value'}]
    items = hash.select { |k, _| keys.include?(k) }.map do |(k, v)|
      { 'code': k, 'monto': v }
    end
    new_hash['items'] = items
  end

  new_hash.transform_keys! { |k| k.strip.special_characters.map_keys.to_sym }
  new_hash.transform_values_types
end

if ARGV.length != 2
  puts "Usage: ruby script.rb <file_path> <item_codes>

  Where:
    file_path: string with full path to the xlsx file
    item_codes: string separated by commas

  Example: ruby script.rb /filename_path.xlsx \"buk_item_code_1,buk_item_code_2\"
  "
  exit 1
end

file_path = ARGV[0]
item_codes = ARGV[1].split(',')

begin
  rows = import_xlsx(file_path)
  result = rows.map { |r| transform_hash(r, item_codes) }
  puts result.inspect
rescue StandardError => e
  puts "Error: #{e.message}"
end
