# frozen_string_literal: true
class Mapper
  ## Find a mapper for a given object
  def self.find(obj)
    new(obj)
  end

  attr_reader :object
  def initialize(object)
    @object = object
  end

  def to_h
    {
      "id": object.id
    }.merge(attribute_hash)
  end

  private

    def attribute_hash
      properties.each_with_object({}) do |property, hsh|
        suffixes.each do |suffix|
          hsh[:"#{property}_#{suffix}"] = object.__send__(property)
        end
      end
    end

    def suffixes
      [
        :ssim,
        :tesim
      ]
    end

    def properties
      object.class.attribute_set.map(&:name) - [:id]
    end
end
