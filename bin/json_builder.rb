#!/usr/bin/env ruby

module GHTorrentWebhook
  class JSON_Builder
    @json
    
    #constructor - initialize @json. This is simply a wrapper for hashes representing JSON objects
    def initialize
      @json = Hash.new
    end
  
    #adds a property to the current hash
    def add_property(property, value)
      @json[property] = value
    end
  
    #adds another JSON object to the current hash (nested JSON object)
    def add_property_object(property, json_obj)
      @json[property] = json_obj.return_object
    end
  
    #returns the full JSON string
    def return_json_string
      return @json.to_s
    end
  
    #adds an array of JSON objects to the current hash
    #the array can be filled with Hashes or JSON_Builders
    def add_array(property, arr)
      @json[property] = Array.new
      arr.each do |build|
        if build.class == JSON_Builder
          @json[property].push(build.return_object)
        else
          @json[property].push(build)
        end
      end
    end
  
    #Takes a JSON object and turns it (excluding sub-JSON objects/children) into a builder
    #Note: This includes arrays, which may indirectly add sub-JSON objects
    def get_JSON_object(object)
      builder = JSON_Builder.new
      object.each do |key, value|
        if object[key].class != Hash
          builder.add_property(key, value)
        end
      end
  
      return builder
    end

    #Adds a JSON object recursively to the current builder. This adds
    #all children of the object as well.
    def add_JSON_object_recursive(property, obj) 
      builder = JSON_Builder.new
      obj.each do |key, value|
        builder.add_property(key, value)
      end

      add_property_object(property, builder)
      return builder
    end 
                                  
    #Returns the actual JSON object (Hash)
    def return_object
      return @json
    end
  end
end
