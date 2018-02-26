# frozen_string_literal: true
module Valkyrie::Persistence::Fedora
  class PermissiveSchema
    URI_PREFIX = 'http://example.com/predicate/'

    # @return [RDF::URI]
    def self.valkyrie_id
      uri_for('valkyrie_id')
    end

    # @return [RDF::URI]
    def self.id
      uri_for(:id)
    end

    # @return [RDF::URI]
    def self.member_ids
      uri_for(:member_ids)
    end

    # Cast the property to a URI in the namespace
    # @param property [Symbol]
    # @return [RDF::URI]
    def self.uri_for(property)
      RDF::URI("#{URI_PREFIX}#{property}")
    end

    attr_reader :schema
    def initialize(schema = {})
      @schema = schema
    end

    def predicate_for(resource:, property:)
      schema.fetch(property) { self.class.uri_for(property) }
    end

    # Find the property in the schema. If it's not there check to see
    # if this prediate is in the URI_PREFIX namespace, return the suffix as the property
    # @example:
    #   property_for(resource: nil, predicate: "http://example.com/predicate/internal_resource")
    #   #=> 'internal_resource'
    def property_for(resource:, predicate:)
      (schema.find { |_k, v| v == RDF::URI(predicate.to_s) } || []).first || predicate.to_s.gsub(URI_PREFIX, '')
    end
  end
end