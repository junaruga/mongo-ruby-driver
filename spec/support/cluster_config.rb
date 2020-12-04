require 'singleton'

class ClusterConfig
  include Singleton
  include RSpec::Core::Pending

  def single_server?
    determine_cluster_config
    @single_server
  end

  def replica_set_name
    determine_cluster_config
    @replica_set_name
  end

  def server_version
    determine_cluster_config
    @server_version
  end

  def enterprise?
    determine_cluster_config
    @enterprise
  end

  def short_server_version
    server_version.split('.')[0..1].join('.')
  end

  def fcv
    determine_cluster_config
    @fcv
  end

  # Per https://jira.mongodb.org/browse/SERVER-39052, working with FCV
  # in sharded topologies is annoying. Also, FCV doesn't exist in servers
  # less than 3.4. This method returns FCV on 3.4+ servers when in single
  # or RS topologies, and otherwise returns the major.minor server version.
  def fcv_ish
    determine_cluster_config
    if server_version.nil?
      raise "Deployment server version not known - check that connection to deployment succeeded"
    end

    if server_version >= '3.4' && topology != :sharded
      fcv
    else
      if short_server_version == '4.1'
        '4.2'
      else
        short_server_version
      end
    end
  end

  # @return [ Mongo::Address ] The address of the primary in the deployment.
  def primary_address
    determine_cluster_config
    @primary_address
  end

  def primary_address_str
    determine_cluster_config
    @primary_address.seed
  end

  def primary_address_host
    both = primary_address_str
    both.split(':').first
  end

  def primary_address_port
    both = primary_address_str
    both.split(':')[1] || 27017
  end

  def primary_description
    determine_cluster_config
    @primary_description
  end

  # Try running a command on the admin database to see if the mongod was
  # started with auth.
  def auth_enabled?
    if @auth_enabled.nil?
      @auth_enabled = begin
        basic_client.use(:admin).command(getCmdLineOpts: 1).first["argv"].include?("--auth")
      rescue => e
        e.message =~ /(not authorized)|(unauthorized)|(no users authenticated)|(requires authentication)/
      end
    end
    @auth_enabled
  end

  def topology
    determine_cluster_config
    @topology
  end

  def storage_engine
    @storage_engine ||= begin
      # 2.6 does not have wired tiger
      if short_server_version == '2.6'
        :mmapv1
      else
        client = ClientRegistry.instance.global_client('root_authorized')
        if topology == :sharded
          shards = client.use(:admin).command(listShards: 1).first
          if shards['shards'].empty?
            raise 'Shards are empty'
          end
          shard = shards['shards'].first
          address_str = shard['host'].sub(/^.*\//, '').sub(/,.*/, '')
          client = ClusterTools.instance.direct_client(address_str,
            SpecConfig.instance.test_options.merge(SpecConfig.instance.auth_options).merge(connect: :direct))
        end
        rv = client.use(:admin).command(serverStatus: 1).first
        rv = rv['storageEngine']['name']
        rv_map = {
          'wiredTiger' => :wired_tiger,
          'mmapv1' => :mmapv1,
        }
        rv_map[rv] || rv
      end
    end
  end

  # This method returns an alternate address for connecting to the configured
  # deployment. For example, if the replica set is configured with nodes at
  # of localhost:27017 and so on, this method will return 127.0.0.:27017.
  #
  # Note that the "alternate" refers to replica set configuration, not the
  # addresses specified in test suite configuration. If the deployment topology
  # is not a replica set, "alternate" refers to test suite configuration as
  # this is the only configuration available.
  def alternate_address
    @alternate_address ||= begin
      address = primary_address_host
      str = case address
      when '127.0.0.1'
        'localhost'
      when /^(\d+\.){3}\d+$/
        skip 'This test requires a hostname or 127.0.0.1 as address'
      else
        # We don't know if mongod is listening on ipv4 or ipv6, in principle.
        # Our tests use ipv4, so hardcode that for now.
        # To support both we need to try both addresses which will make this
        # test more complicated.
        #
        # JRuby chokes on primary_address_port as the port (e.g. 27017).
        # Since the port does not actually matter, use a common port like 80.
        resolved_address = Addrinfo.getaddrinfo(address, 80, Socket::PF_INET).first.ip_address
        if resolved_address.include?(':')
          "[#{resolved_address}]"
        else
          resolved_address
        end
      end + ":#{primary_address_port}"
      Mongo::Address.new(str)
    end
  end

  private

  def determine_cluster_config
    p "[DEBUG] spec/support/cluster_config.rb determine_cluster_config init primary_address: #{@primary_address}"
    return if @primary_address
    p "[DEBUG] spec/support/cluster_config.rb determine_cluster_config after 1st return."

    # Run all commands to figure out the cluster configuration from the same
    # client. This is somewhat wasteful when running a single test, but reduces
    # test runtime for the suite overall because all commands are sent on the
    # same connection rather than each command connecting to the cluster by
    # itself.
    client = ClientRegistry.instance.global_client('root_authorized')

    primary = client.cluster.next_primary
    @primary_address = primary.address
    @primary_description = primary.description
    @replica_set_name = client.cluster.topology.replica_set_name

    @topology ||= begin
      topology = client.cluster.topology.class.name.sub(/.*::/, '')
      topology = topology.gsub(/([A-Z])/) { |match| '_' + match.downcase }.sub(/^_/, '')
      if topology =~ /^replica_set/
        topology = 'replica_set'
      end
      topology.to_sym
    end

    @single_server = client.cluster.servers_list.length == 1

    build_info = client.database.command(buildInfo: 1).first

    # Debug
    p "[DEBUG] spec/support/cluster_config.rb determine_cluster_config build_info: #{build_info}"

    @server_version = build_info['version']
    @enterprise = build_info['modules'] && build_info['modules'].include?('enterprise')

    if @topology != :sharded && short_server_version >= '3.4'
      rv = client.use(:admin).command(getParameter: 1, featureCompatibilityVersion: 1).first['featureCompatibilityVersion']
      @fcv = rv['version'] || rv
    end
  end

  def basic_client
    # Do not cache the result here so that if the client gets closed,
    # client registry reconnects it in subsequent tests
    ClientRegistry.instance.global_client('basic')
  end
end
