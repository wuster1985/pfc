Puppet::Parser::Functions::newfunction(:create_resources, :doc => <<-'ENDHEREDOC') do |args|
    Converts a hash into a set of resources and adds them to the catalog.

    This function takes two arguments: a resource type, and a hash describing
    a set of resources. The hash should be in the form `{title => {parameters} }`:

        # A hash of user resources:
        $myusers = {
          'nick' => { uid    => '1330',
                      group  => allstaff,
                      groups => ['developers', 'operations', 'release'], }
          'dan'  => { uid    => '1308',
                      group  => allstaff,
                      groups => ['developers', 'prosvc', 'release'], }
        }

        create_resource(user, $myusers)

    This function can be used to create defined resources and classes, as well
    as native resources.
  ENDHEREDOC
  raise ArgumentError, ("create_resources(): wrong number of arguments (#{args.length}; must be 2)") if args.length != 2
  #raise ArgumentError, 'requires resource type and param hash' if args.size < 2
  # figure out what kind of resource we are
  type_of_resource = nil
  type_name = args[0].downcase
  if type_name == 'class'
    type_of_resource = :class
  else
    if resource = Puppet::Type.type(type_name.to_sym)
      type_of_resource = :type
    elsif resource = find_definition(type_name.downcase)
      type_of_resource = :define
    else
      raise ArgumentError, "could not create resource of unknown type #{type_name}"
    end
  end
  # iterate through the resources to create
  args[1].each do |title, params|
    raise ArgumentError, 'params should not contain title' if(params['title'])
    case type_of_resource
    # JJM The only difference between a type and a define is the call to instantiate_resource
    # for a defined type.
    when :type, :define
      p_resource = Puppet::Parser::Resource.new(type_name, title, :scope => self, :source => resource)
      params.merge(:name => title).each do |k,v|
        p_resource.set_parameter(k,v)
      end
      if type_of_resource == :define then
        resource.instantiate_resource(self, p_resource)
      end
      compiler.add_resource(self, p_resource)
    when :class
      klass = find_hostclass(title)
      raise ArgumentError, "could not find hostclass #{title}" unless klass
      klass.ensure_in_catalog(self, params)
      compiler.catalog.add_class([title])
    end
    when :cloudres
       ### TODO What?
    end
  end
end
