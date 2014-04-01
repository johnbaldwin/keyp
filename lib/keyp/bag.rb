module Keyp
  # ----------------------------------------------

  # Some inspiration:
  # http://stackoverflow.com/questions/2680523/dry-ruby-initialization-with-hash-argument
  #
  # TODO: add handling so that keys (hierarchical keys too) are accessed as members instead of
  # hash access
  #
  # TODO: move to own file, rename to "Bag"
  # TODO: i18n error messages
  #
  class Keyper

    attr_reader :keypdir, :dirty
    attr_accessor :name, :data, :file_hash

    def keypfile
      File.join(@keypdir, @name+@ext)
    end

    # We expect
    # I'm not happy with how creating instance variables works. There must be a cleaner way
    def initialize(name, options = {})
      @name = name
      options.each do |k,v|
        puts "processing options #{k} = #{v}"
        instance_variable_set("@#{k}", v) unless v.nil?
      end
      # set attributes not set by params

      @keypdir ||= Keyp::home
      @read_only ||= false
      @ext ||= Keyp::DEFAULT_EXT
      #@keypfile = config_path
      # load our resource

      # load config file into hashes
      # not the most efficient thing, but simpler and safe enough for now

      unless File.exist? keypfile
        puts "Keyper.initialize, create_bag #{keypfile}"
        Keyp::create_bag(name)
      end
      file_data = load(keypfile)

      @meta = file_data[:meta]
      @data = file_data[:data]|| {}
      @file_hash = file_data[:file_hash]
      @dirty = false
    end

    def [](key)
      @data[key]
    end

    def []=(key, value)
      set_prop(key, value)
    end

    def set_prop(key, value)
      unless @read_only
        # TODO: check if data has been modified
        # maybe there is a way hash tells us its been modified. If not then
        # just check if key,val is already in hash and matches
        @data[key] = value
        @dirty = true
      else
        raise "Bag #{@name} is read only"
      end
    end

    def delete(key)
      unless @read_only
        if @data.key? key
          @dirty = true
        end
        val = @data.delete(key)
      else
        raise "Bag #{@name} is read only"
      end
      val
    end

    def empty?
      @data.empty?
    end


    ##
    # Adds key/value pairs from this bag to the Ruby ENV
    # NOTE: Currently in development.
    # If no options are provided, then all of the bag's key/value pairs will be assigned.
    #
    # ==== Options
    # TBD:
    #  +:sysvar+ Only use valid system environment vars
    #  +:selection+ Provide a list of keys to match
    #  +:overwrite+
    #  +:no_overwrite+  - This is enabled by default
    #  +:to_upper

    # Returns a hash of the key/value pairs which have been set
    # ==== Examples
    # +add_to_env upper:+
    # To assign keys matching a pattern:
    # +add_to_env regex: '\A(_|[A-Z])[a-zA-Z\d]*'

    def add_to_env(options = {})
      # TODO: Add checking, upcase

      # pattern matching valid env var
      sys_env_reg = /\A(_|[a-zA-Z])\w*/
      assigned = {}
      overwrite = options[:overwrite] || false
      pattern = options[:sysvar] if options.key?(:sysvar)

      pattern ||= '(...)'

      bag.data.each do |key,value|
        if pattern.match(key)
          # TODO: add overwrite checking
          ENV[key] = value
          assigned[key] = value
        end
      end
      assigned
    end


    # TODO add from hash


    def import(filename)
      raise "import not yet supported"
    end

    def export(filename)
      raise "export not yet supported"
    end


    # TODO: def to_yaml
    # TODO: def to_json
    # TODO: def to_s

    ##
    # Give full path, attempt to load
    # sticking with YAML format for now
    # May add new file format later in which case we'll
    # TODO: consider changing to class method
    def load (config_path)
      #config_data = {}
      # Get extension
      file_ext = File.extname(config_path)

      # check
      # only YAML supported for initial version. Will consider adapters to
      # abstract the persistence layer


      # TODO: make this hardcoded case a hash of helpers
      # TODO: Add two sections: Meta and data, then return as hash

      if file_ext.downcase == Keyp::DEFAULT_EXT

        # Either we are arbitrarily creating directories when
        # given a path for a file that doesn't exist
        # or we have special behavior for the default dir
        # or we just fault and let the caller deal with it
        unless File.exist? config_path
          raise "Keyp config file not found: #{config_path}"
        end

        file_data = YAML.load_file(config_path)

      else
        raise "Keyp version x only supports YAML for config files. You tried a #{file_ext}"
      end
      { meta: file_data['meta'], data: file_data['data']||{}, file_hash: file_data.hash }
    end

    ##
    # Saves the Bag to file
    #
    # NOT thread safe
    # TODO: make thread safe
    def save
      if @read_only
        raise "This bag instance is read only"
      end
      if @dirty
        # lock file
        # read checksum
        # if checksum matches our saved checksum then update file and release lock
        # otherwise, raise
        # TODO: implement merge from updated file and raise only if conflict
        begin
          file_data = { 'meta' => @meta, 'data' => @data }

          if File.exist? keypfile
            read_file_data = load(keypfile)
            unless @file_hash == read_file_data[:file_hash]
              raise "Will not write to #{keypfile}\nHashes differ. Expected hash =#{@file_hash}\n" +
                        "found hash #{read_file_data[:file_hash]}"
            end
          end
          File.open(keypfile, 'w') do |f|
            f.write file_data.to_yaml
          end
          @dirty = false
        rescue
          # TODO: log error

        end
      end
    end
  end
end